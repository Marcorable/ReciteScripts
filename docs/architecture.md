# Flutter 프로젝트 구조와 네이티브 STT 브리지

> Issue #23 산출물. Flutter 공식 App Architecture Guide를 기본으로 삼고 말또의 세션·매칭·온디바이스 STT 제약에 맞게 구체화한다.
> Marco가 선택한 로컬 저장 기술은 **drift + SQLite**다. 이 문서의 구조·의존 방향·브리지 선택은 후속 구현의 기준이다.

## 1. 결정 요약

| 항목 | 결정 |
|---|---|
| 프로젝트 구조 | feature-first. 각 사용자 기능 안에서 View와 ViewModel을 함께 두고, 공유 도메인과 인프라는 명시적인 경계로 분리한다. |
| 기본 의존 방향 | `View → ViewModel → Repository → Service`. 아래 계층은 위 계층을 import하지 않는다. |
| 복잡한 순수 로직 | 낭독 세션 상태 전이와 매칭은 Flutter·저장소·플랫폼 API를 모르는 순수 Dart 도메인으로 둔다. Repository가 이를 조합한다. |
| 로컬 저장 | drift + SQLite. 앱 모델과 drift 생성 타입 사이를 Repository 구현이 변환한다. |
| 네이티브 브리지 | Pigeon의 platform-channel 방식을 사용한다. 생성 코드는 앱 내부 전송 세부사항이며 공개 Dart 계약으로 노출하지 않는다. |
| STT 경계 | Dart `SttService` 하나와 iOS·Android 네이티브 어댑터를 둔다. 권한·지원·모델 준비·부분/최종 결과·오류·취소를 공통 타입으로 정규화한다. |
| 세션 소유권 | `ReadingSessionRepository`가 활성 세션의 단일 진실 공급원이다. ViewModel은 네이티브 핸들, drift 행, 매칭 엔진을 직접 다루지 않는다. |

Flutter 공식 가이드는 UI와 데이터 계층을 나누고 View, ViewModel, Repository, Service를 각기 명확한 입력과 출력으로 분리하도록 권장한다. Repository는 앱 데이터의 단일 진실 공급원이고 Service는 플랫폼 API나 로컬 파일 같은 외부 데이터원을 감싼다. 말또는 이 방향을 그대로 사용하되, 재사용되고 복잡한 세션·매칭 규칙에만 선택적인 순수 Dart 도메인 계층을 둔다.

## 2. 디렉터리 구조

제품 Flutter 앱을 만들 때 다음 골격을 사용한다. 이름은 역할을 나타내며 화면 수에 맞춰 파일을 더 나눌 수 있다.

```text
lib/
└── src/
    ├── app/
    │   ├── app.dart
    │   ├── router.dart
    │   └── dependencies.dart
    ├── features/
    │   ├── scripts/
    │   │   ├── presentation/
    │   │   │   ├── script_list_view.dart
    │   │   │   ├── script_list_view_model.dart
    │   │   │   ├── script_add_view.dart
    │   │   │   └── script_add_view_model.dart
    │   │   ├── model/script.dart
    │   │   └── data/
    │   │       ├── script_repository.dart
    │   │       └── drift_script_repository.dart
    │   └── reading/
    │       ├── presentation/
    │       │   ├── reading_setup_view.dart
    │       │   ├── reading_setup_view_model.dart
    │       │   ├── reading_view.dart
    │       │   └── reading_view_model.dart
    │       ├── domain/
    │       │   ├── cursor_matcher.dart
    │       │   ├── reading_session.dart
    │       │   └── reading_session_reducer.dart
    │       └── data/
    │           ├── reading_session_repository.dart
    │           └── local_reading_session_repository.dart
    ├── infrastructure/
    │   ├── database/
    │   │   ├── app_database.dart
    │   │   ├── database_service.dart
    │   │   ├── tables/scripts.dart
    │   │   └── migrations/
    │   └── stt/
    │       ├── stt_service.dart
    │       ├── stt_models.dart
    │       ├── pigeon_stt_service.dart
    │       └── generated/
    └── shared/
        ├── localization/
        └── widgets/
pigeons/
└── stt_api.dart
drift_schemas/
test/
├── features/
├── infrastructure/
└── migrations/
```

구조 규칙은 다음과 같다.

- `features/`의 최상위 단위는 사용자가 인식하는 기능이다. 기술 종류별 전역 `views/`, `view_models/` 폴더를 만들지 않는다.
- View와 ViewModel은 한 기능의 `presentation/`에 함께 둔다. View에는 표시·레이아웃·애니메이션·단순 라우팅만 남긴다.
- Repository 추상 계약은 이를 사용하는 기능이 소유한다. 구현은 같은 기능의 `data/`에 두되, drift와 Pigeon 생성 타입은 `infrastructure/` 밖으로 새지 않는다.
- `reading/domain/`은 순수 Dart다. `package:flutter`, drift, Pigeon, MethodChannel, Swift/Kotlin 개념을 import하지 않는다.
- `infrastructure/`는 SQLite와 플랫폼 STT처럼 Dart 앱 밖의 데이터원에 접근하는 Service와 생성 코드를 소유한다.
- `app/dependencies.dart`만 구체 구현을 조립한다. View나 ViewModel에서 데이터베이스 또는 채널 구현을 직접 생성하지 않는다.
- 범용화가 확인되지 않은 코드는 `shared/`로 먼저 옮기지 않는다. 기능 소유권을 우선한다.

## 3. 의존 방향과 경계

```text
View
  ↓ 사용자 이벤트 / UI state
ViewModel
  ↓ 앱 작업 / 도메인 모델
Repository (추상 계약, 단일 진실 공급원)
  ├─→ pure Dart session + matcher
  └─→ Service (drift database 또는 platform STT)
         ↓
      SQLite / Pigeon / Swift / Kotlin
```

허용되는 책임은 다음과 같다.

| 구성요소 | 책임 | 금지 |
|---|---|---|
| View | ViewModel의 불변 UI 상태 표시, 사용자 이벤트 전달, 접근성·레이아웃 | 비즈니스 규칙, SQL, STT 호출, 매칭 |
| ViewModel | Repository 결과를 UI 상태로 변환, 화면 명령 처리, 구독 해제 | drift 타입, Pigeon 타입, 네이티브 오류 코드 해석 |
| Repository | 앱 모델의 단일 진실 공급원, Service 결과 정규화, 세션·매칭 조합 | Widget/BuildContext 참조, 다른 Repository 직접 참조 |
| Domain | 세션 상태 전이, 순방향 커서, 반복 완료, 텍스트 정규화·유사도 | Flutter, 저장, 채널, 플랫폼 참조 |
| Service | SQLite 쿼리 또는 플랫폼 호출의 얇은 래퍼 | UI 상태, 매칭 임계값, 반복 규칙 |

Repository 두 개의 데이터를 함께 써야 하는 화면은 ViewModel에서 조합한다. 조합이 복잡하거나 재사용될 때만 use-case를 추가하며, 모든 호출을 형식적인 use-case로 감싸지는 않는다.

### 경계별 소유권

- **UI 경계:** `scripts`와 `reading` View/ViewModel. 낭독 View는 `ReadingUiState`만 읽고 `start`, `moveBackOneWord`, `leave` 같은 명령만 보낸다.
- **세션 경계:** `ReadingSessionRepository`와 순수 Dart reducer. 세션 ID, 현재 회차, 목표 회차, 커서, 종료 여부, 현재 STT generation을 소유한다.
- **매칭 경계:** `CursorMatcher`. 원문 범위를 보존한 어절과 전사문을 받아 새 커서 후보만 반환한다. UI와 STT 이벤트 타입을 알지 못하며 자동으로 커서를 뒤로 보내지 않는다.
- **저장 경계:** `ScriptRepository`가 앱의 `Script` 모델을 노출한다. drift 행·companion·DAO는 구현 내부에만 존재한다.
- **STT 경계:** `SttService`가 공통 준비 상태와 이벤트를 노출한다. Pigeon 메시지와 iOS/Android 오류는 구현에서 공통 모델로 바꾼다.

## 4. 낭독 세션과 동시성

`ReadingSessionRepository`는 메모리 안의 활성 낭독 세션을 관리한다. 낭독 진행은 영속화하지 않으며, 대본만 `ScriptRepository`를 통해 저장한다.

1. ViewModel이 대본과 목표 횟수로 `start()`를 요청한다.
2. Repository가 새 불투명 `sessionId`와 0부터 증가하는 `generation`을 만들고 순수 세션 상태를 초기화한다.
3. `SttService.prepare(locale: 'ko-KR')`로 권한·온디바이스 지원·모델 준비를 확인한 뒤 같은 식별자로 인식을 시작한다.
4. STT 이벤트는 `sessionId`와 `generation`이 현재 값과 모두 같을 때만 matcher에 전달한다.
5. matcher 결과를 reducer에 적용한다. 부분 결과가 수정되어도 자동 진행 커서는 감소하지 않고, 한 어절 뒤로 명령만 감소시킨다.
6. 새 회차를 시작할 때 generation을 올리고 이전 전사 구간을 폐기한 뒤 새 네이티브 인식 작업을 시작한다.
7. 나가기·완료·백그라운드 진입 시 먼저 세션을 종료 상태로 바꾸고 generation을 무효화한 다음 STT를 취소하고 Dart 구독을 닫는다.
8. 취소 뒤 도착한 이벤트, 중복 최종 이벤트, 종료된 세션 이벤트는 조용히 버린다. 사용자 대본이나 전사문을 로그에 남기지 않는다.

ViewModel의 `dispose`도 구독을 취소하지만 자원 종료의 유일한 방어선으로 삼지 않는다. 앱 생명주기에서 background/inactive 전환을 받으면 Repository에 중단을 명시적으로 요청하며 자동 재개하지 않는다.

## 5. drift + SQLite 저장 설계

### Repository 계약

초기 계약은 MVP 작업만 노출한다. drift 타입은 포함하지 않는다.

```dart
abstract interface class ScriptRepository {
  Stream<List<Script>> watchAll();
  Future<Script?> getById(ScriptId id);
  Future<Script> create({required String title, required String body});
  Future<void> delete(ScriptId id);
}
```

- `watchAll()`은 목록 화면의 단일 진실 공급원이다.
- 입력의 공백 검증은 ViewModel에서 즉시 피드백하고 Repository에서도 불변조건으로 방어한다.
- 삭제는 트랜잭션으로 처리한다. MVP에는 대본 편집·묶음·통계 API를 미리 추가하지 않는다.
- Repository 테스트에는 메모리 SQLite를 사용하고 ViewModel 테스트에는 가짜 Repository를 사용한다.

### v1 스키마

`scripts` 테이블만 만든다.

| 열 | SQLite/drift | 규칙 |
|---|---|---|
| `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | 저장소 내부 식별자. 앱에는 값 객체로 변환한다. |
| `title` | `TEXT NOT NULL` | trim 후 비어 있지 않아야 한다. |
| `body` | `TEXT NOT NULL` | 원문 그대로 저장하되 공백뿐인 값은 거부한다. |
| `created_at` | `INTEGER NOT NULL` | UTC 시각. 정렬과 향후 마이그레이션의 안정적인 기준이다. |

MVP 요구에 없는 `updated_at`, 진행률, 반복 통계, 묶음 외래 키, 동기화 메타데이터는 넣지 않는다. 본문 검색용 FTS도 현재 범위 밖이다.

### 마이그레이션 전략

- `schemaVersion`은 1에서 시작하고 배포된 스키마를 바꿀 때마다 정확히 1 이상 증가시킨다.
- drift의 guided migration을 사용한다. 현재 스키마를 `drift_schemas/`에 버전별 JSON으로 보관하고 `dart run drift_dev make-migrations`가 만든 단계별 마이그레이션과 테스트를 검토한다.
- 생성됐다는 이유만으로 마이그레이션을 신뢰하지 않는다. 이전 버전 DB에 직접 작성한 더미 데이터(예: 제목 `아침 연습`, 본문 `창문을 열고 천천히 문장을 읽는다.`)를 넣고 최신 버전으로 올린 뒤 행과 제약을 검증한다.
- 모든 지원 시작 버전에서 최신 버전까지의 업그레이드와 빈 DB 생성 결과가 같은 스키마인지 검사한다. downgrade와 자동 파괴 재생성은 지원하지 않는다.
- 열 추가는 가능한 한 nullable 또는 안전한 기본값으로 먼저 추가한다. 테이블 재작성·데이터 변환은 한 트랜잭션에서 수행하고, 실패하면 기존 DB를 보존한다.
- 스키마 스냅샷과 마이그레이션 테스트는 앱 코드와 함께 커밋한다. 사용자 DB 파일이나 실제 사용자 텍스트는 픽스처로 사용하지 않는다.
- DB 연결은 앱 범위에서 하나만 소유하고 종료 시 닫는다. ViewModel과 Widget이 연결 생명주기를 관리하지 않는다.

## 6. MethodChannel과 Pigeon 비교

| 기준 | MethodChannel 직접 사용 | Pigeon platform channels |
|---|---|---|
| 계약 표현 | 채널명·메서드명 문자열, `Map` 키, 수동 cast | 한 Dart 스키마에서 Dart/Swift/Kotlin 타입 생성 |
| 컴파일 시 검출 | 이름·필드 불일치는 런타임에 발견 | 지원 타입·메서드 시그니처 불일치를 더 일찍 발견 |
| 비동기 이벤트 | EventChannel 또는 별도 callback channel을 수동 설계 | `@EventChannelApi` 또는 `@FlutterApi` 생성 계약 사용 가능 |
| 오류 정규화 | 직접 envelope와 변환 작성 | 전송 코드는 생성되지만 도메인 오류 변환은 여전히 직접 작성 |
| 유지 비용 | 작은 호출에는 단순하나 세 플랫폼 코드를 수동 동기화 | codegen과 생성물 관리가 필요하지만 계약 변경을 한곳에서 시작 |
| 버전 위험 | 앱이 자체 채널 호환성을 관리 | 양쪽 생성물을 같은 Pigeon 버전으로 함께 재생성해야 함 |

**선택: Pigeon의 안정된 platform-channel 전송 방식.** 실험적인 native interop(FFI/JNI)은 사용하지 않는다.

선택 이유는 STT가 단발 호출이 아니라 준비 상태, 세션 시작/취소, 부분/최종 결과, 모델 상태와 구조화된 오류를 양방향으로 전달하기 때문이다. 타입 생성으로 세 언어의 계약 드리프트를 줄이는 효과가 codegen 비용보다 크다. Pigeon도 내부적으로 platform channels와 `StandardMessageCodec`을 사용하므로 비동기 메시지 경계 자체가 없어지는 것은 아니다.

운영 규칙은 다음과 같다.

- `pigeons/stt_api.dart`가 전송 계약의 단일 원본이다. 선언 파일에는 로직을 넣지 않는다.
- Pigeon 버전을 고정하고 Dart/Swift/Kotlin 생성물을 한 명령으로 함께 갱신한다. 서로 다른 버전의 생성물을 섞지 않는다.
- 생성 코드를 앱의 Repository 또는 ViewModel API에서 반환하지 않는다. `PigeonSttService`가 안정된 `SttStatus`, `SttEvent`, `SttFailure`로 변환한다.
- 채널 이름, 원시 `Map`, 플랫폼 정수 오류 코드를 UI나 도메인에 노출하지 않는다.
- 시작·취소·상태 확인 명령은 Host API, 연속 결과는 Pigeon EventChannel API를 우선 사용한다. 도입 시 고정한 Pigeon 버전의 EventChannel 생성이 양 플랫폼에서 검증되지 않으면 `FlutterApi` callback을 같은 typed schema 안의 대안으로 사용한다.
- 생성 결과는 직접 수정하지 않는다. 생성 여부와 정합성을 CI에서 재생성 diff 또는 전용 검사로 확인한다.

## 7. 공통 STT 계약

Dart 앱이 의존하는 계약은 Pigeon과 독립적이다.

```dart
abstract interface class SttService {
  Future<SttAvailability> checkAvailability({required String locale});
  Future<SttPreparation> prepare({required String locale});
  Stream<SttEvent> events(String sessionId);
  Future<void> start(SttStartRequest request);
  Future<void> cancel(String sessionId);
  Future<void> dispose();
}
```

### 공통 값과 이벤트

- `SttAvailability`: 권한 상태, 온디바이스 엔진 가용성, 로케일 지원, 모델 설치 여부를 각각 표현한다. 하나의 `available: bool`로 원인을 잃지 않는다.
- `SttPreparation`: `ready`, `permissionRequired`, `permissionDenied`, `modelDownloadRequired`, `modelDownloading`, `unsupported`를 구분한다.
- `SttStartRequest`: `sessionId`, `generation`, 정규화된 BCP-47 locale(`ko-KR`)만 전달한다. 대본은 네이티브로 전달하지 않는다.
- `SttEvent`: 모든 variant가 `sessionId`, `generation`, 단조 증가하는 `sequence`를 가진다.
  - `ready`: 마이크 입력을 받을 준비가 됨.
  - `partial`: 현재 인식 구간의 수정 가능한 전사.
  - `finalResult`: 현재 인식 구간의 확정 전사.
  - `ended`: 정상 입력 종료. 세션 전체 완료 의미가 아니며 Repository가 재시작 여부를 결정한다.
  - `failure`: 정규화된 오류와 재시도 가능 여부.
  - `cancelled`: 취소가 네이티브에서 정리됨.
- `SttFailureCode`: `permissionDenied`, `onDeviceUnavailable`, `localeUnsupported`, `modelMissing`, `busy`, `noMatch`, `audio`, `interrupted`, `cancelled`, `unknown`을 최소 집합으로 둔다. 플랫폼 원시 메시지는 개발 로그에도 대본·전사문 없이 진단 코드만 남긴다.

`partial`과 `finalResult`의 text는 빈 문자열이 아닐 때만 보낸다. 같은 sequence를 두 번 적용하지 않으며, stream 종료만으로 완료를 추론하지 않는다. `cancel()`은 여러 번 호출해도 안전해야 하고 이미 끝난 세션에는 성공으로 응답한다.

## 8. iOS 어댑터 계약과 생명주기

iOS 26+ 구현은 `SpeechAnalyzer`와 `SpeechTranscriber`를 사용한다.

1. 마이크 및 Speech 권한을 확인한다. 거부 상태에서는 오디오 세션이나 분석기를 시작하지 않는다.
2. `SpeechTranscriber.isAvailable`과 `supportedLocale(equivalentTo:)`로 기기·`ko-KR` 지원을 확인한다.
3. `installedLocales`를 확인하고 필요하면 `AssetInventory.assetInstallationRequest(supporting:)`로 설치 요청을 만든다. 다운로드는 사용자에게 상태를 알린 뒤 명시적으로 수행하며, 준비 전 인식을 시작하지 않는다.
4. `.fastResults`를 포함한 transcriber를 만들고 volatile 결과는 `partial`, finalized 결과는 `finalResult`로 보낸다.
5. `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`와 실제 입력 포맷이 다르면 `AVAudioConverter`로 변환한다. 스파이크에서 확인한 `.playAndRecord` + `.spokenAudio` 구성을 사용한다.
6. audio tap, 입력 AsyncStream, 결과 소비 Task, analyzer를 한 native session 객체가 소유한다. 객체는 sessionId와 generation을 캡처한다.
7. 취소·백그라운드·오류 시 새 결과 발행을 먼저 막고 audio tap을 제거한 뒤 입력을 끝내고 Task/analyzer/audio session을 정리한다. 늦은 async 결과는 식별자 검사 후 버린다.
8. `SpeechTranscriber`가 기기에서 사용할 수 없는 경우 스파이크에서 검토한 `DictationTranscriber` 폴백을 어댑터 내부에서만 선택한다. 네트워크 STT로 전환하지 않는다.

음성 버퍼를 파일로 기록하지 않고, 전사문·사용자 대본을 OS 로그나 분석 도구에 남기지 않는다.

## 9. Android 어댑터 계약과 생명주기

Android 13/API 33+ 구현은 시스템의 on-device `SpeechRecognizer`만 사용한다.

1. `RECORD_AUDIO` 권한과 `SpeechRecognizer.isOnDeviceRecognitionAvailable(context)`를 확인한다. false이면 일반 `createSpeechRecognizer`로 폴백하지 않는다.
2. 메인 스레드에서 `createOnDeviceSpeechRecognizer`, `setRecognitionListener`, `startListening`을 호출한다.
3. 요청 Intent는 `ko-KR`, free-form language model, partial results, offline preference를 지정한다. extra는 서비스가 무시할 수 있으므로 이것만으로 온디바이스 동작을 주장하지 않는다.
4. API 33 `checkRecognitionSupport`로 언어의 설치·지원 상태를 구분하고 필요하면 `triggerModelDownload`를 호출한다. 실제 비행기 모드 검증은 Issue #36의 출시 게이트로 유지한다.
5. `onReadyForSpeech`는 `ready`, `onPartialResults`는 `partial`, `onResults`는 `finalResult`, `onError`는 정규화된 `failure`로 변환한다. RMS와 원시 오디오 이벤트는 Dart로 보내거나 저장하지 않는다.
6. 한 recognizer에는 한 활성 native session만 둔다. `startListening` 후 `onResults` 또는 `onError`가 올 때까지 같은 recognizer에서 다시 시작하지 않는다.
7. 사용자의 나가기는 `cancel()`이고, `stopListening()`은 발화 종료 후 결과를 요구하는 경우에만 사용한다. cancel/terminal callback 뒤 새 generation으로 재시작한다.
8. Activity detach, 앱 background, Service dispose 시 `cancel()` 후 `destroy()`를 메인 스레드에서 호출하고 listener 참조를 해제한다. 종료 뒤 callback은 식별자 검사 후 버린다.

제조사별 인식 서비스가 부분 결과를 보내지 않을 수 있으므로 Repository는 부분 결과 횟수를 가정하지 않는다. `noMatch`는 커서를 움직이지 않는 복구 가능한 종료이고, busy/client 오류는 이전 세션 정리 여부를 확인한 뒤에만 제한적으로 재시도한다.

## 10. 테스트와 검증 기준

### 자동 테스트

- matcher와 reducer: Flutter 없이 순수 Dart 테스트. 순방향 진행, 명시적 한 어절 뒤로, 반복 경계, 중복·늦은 이벤트, generation 교체를 검증한다.
- Repository: 가짜 Service로 단일 진실 공급원과 오류 변환을 테스트한다.
- drift: 메모리 SQLite CRUD, stream 갱신, 제약, 삭제 트랜잭션을 테스트한다.
- migration: 모든 보관 스키마에서 최신 버전으로 올리고 데이터 보존과 최종 스키마 동일성을 검사한다.
- ViewModel: 가짜 Repository로 UI 상태와 명령을 테스트한다.
- Pigeon: 생성 코드가 최신인지 확인하고 iOS/Android host 계약의 직렬화·오류 매핑 테스트를 둔다.

### 통합·기기 검증

- 권한 미결정/거부, `ko-KR` 미지원, 모델 미설치/설치, 준비 성공을 양 플랫폼에서 확인한다.
- 부분→수정된 부분→최종, no-match, 취소, background, 재진입, 회차 전환, 종료 뒤 늦은 결과를 확인한다.
- 비행기 모드에서 사용자 음성·전사문이 기기 밖으로 나가지 않고 실제 한국어 인식이 동작하는지 실기기로 확인한다.
- 코드 변경 시 `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, Android/iOS 빌드·실행·스크린샷의 저장소 검증 루프를 따른다.

이 Issue는 설계 문서만 변경하므로 Markdown 링크, 금지 텍스트, 미정 상태의 잔존 여부와 변경 diff를 검사한다. 제품 앱을 만드는 후속 Issue부터 위 자동·통합 검증을 적용한다.

## 11. 공식 자료

- [Flutter Guide to app architecture](https://docs.flutter.dev/app-architecture/guide)
- [Flutter Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- [Flutter Platform-specific code and Pigeon](https://docs.flutter.dev/platform-integration/platform-channels)
- [Pigeon package documentation](https://pub.dev/packages/pigeon)
- [drift Migrations](https://drift.simonbinder.eu/migrations/)
- [drift Testing migrations](https://drift.simonbinder.eu/migrations/tests/)
- [Apple SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- [Apple AssetInventory](https://developer.apple.com/documentation/speech/assetinventory)
- [WWDC25: Bring advanced speech-to-text to your app with SpeechAnalyzer](https://developer.apple.com/videos/play/wwdc2025/277/)
- [Android SpeechRecognizer](https://developer.android.com/reference/android/speech/SpeechRecognizer)
- [Android RecognitionListener](https://developer.android.com/reference/android/speech/RecognitionListener)

공식 자료는 2026-10-26에 다시 확인했다. 패키지 버전과 플랫폼 API 세부사항은 구현 Issue에서 고정 버전을 선택하기 직전에 다시 확인한다.
