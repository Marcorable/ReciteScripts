# STT 스파이크 — 한국어 실시간 어절 추적 검증 (Issue #12)

> 2026-09-21. 스파이크 코드는 `spikes/stt/`에 있고 **버리는 코드**다.
> 이 문서가 산출물이다: 3종 테스트 결과, 지연 체감, 오인식 패턴, 하이라이트 단위 권고.

## 1. 환경

| 항목 | 값 |
|---|---|
| Xcode | 26.6 (17F113), iOS 26.5 SDK |
| 실기기 | iPhone 12 Pro — 테스트 전 iOS 18.7.8 → iOS 26 업데이트 필요 |
| 시뮬레이터 | iPhone 17 (iOS 26.5). `SpeechTranscriber.isAvailable == false` → 인식 검증 불가, UI 검증만 |
| API | `SpeechAnalyzer` + `SpeechTranscriber(locale: ko-KR)`, `reportingOptions: [.volatileResults]`, `attributeOptions: [.audioTimeRange]` |

## 2. 구현 요약

```
spikes/stt/
├── ScriptTracker/          순수 Swift 패키지 (매칭 로직, swift test 24개)
│   ├── TextNormalizer      공백·문장부호 제거 → 한글 자모 분해(NFD)
│   ├── ScriptTokenizer     공백 기준 어절 분리
│   ├── CursorMatcher       앵커 이후 어절과만 편집거리 DP 정렬, 커서 앞으로만
│   └── ReadingSession      volatile/final 처리, 수동 넘김 폴백
├── STTSpike/               SwiftUI 앱 (버리는 코드)
│   ├── SpeechPipeline      마이크 → AVAudioConverter → SpeechAnalyzer
│   ├── SpikeModel          이벤트 → 커서·지연 측정·로그
│   └── ContentView         대본 하이라이트 + 자동 스크롤 + 진단 UI
└── Harness/                macOS CLI. TTS 오디오를 실시간 속도로 넣어 파이프라인 재현 (README 참고)
```

### 매칭 방식

- **자모 스트림 정렬.** 한국어 STT의 띄어쓰기는 대본과 다르게 나온다("소리내어" vs "소리 내어"). 어절 단위 비교 대신, 앵커 이후 어절들을 이어 붙인 자모열과 발화 자모열을 편집거리로 정렬하고 어절 경계마다 정규화 거리를 구한다.
- **앵커/커서 분리.** 확정(final) 결과로만 앵커를 옮기고, 임시(volatile) 결과는 커서만 앞으로 당긴다. 커서는 절대 뒤로 가지 않는다.
- **탐색 범위 제한.** 발화 길이의 1.6배(최소 4어절)까지만 앞을 본다. 전체 대본 검색 없음 → 반복 낭독·반복 어절에서 안전.
- **임계값** 기본 0.45 (정규화 편집거리). 앱에서 슬라이더로 조정 가능.

### 확인한 함정

- `AVAudioEngine.inputNode.outputFormat` ≠ `SpeechAnalyzer.bestAvailableAudioFormat` → 에러 없이 전사 0건. `AVAudioConverter`로 변환한다. iOS 27에 추가된 `AnalyzerInputConverter`는 iOS 26 타깃에서 못 쓴다(SDK `.swiftinterface`에서 확인).
- `Mutex`는 `~Copyable`이라 오디오 탭 클로저에 직접 캡처할 수 없다 → `AudioClock` 클래스로 감쌌다.
- `AVAudioConverterInputBlock`은 `NS_SWIFT_SENDABLE`이라 `AVAudioPCMBuffer`를 `@unchecked Sendable` 박스로 넘겨야 한다.
- 시뮬레이터는 `SpeechTranscriber.isAvailable == false`. 인식은 실기기에서만.

## 3. 측정 방법

- **지연** = (지금까지 분석기에 넣은 오디오 초) − (결과의 `range.end` 초). 결과가 도착한 시점에 오디오가 얼마나 앞서 있는지. 임시 결과의 지연이 "자막처럼 느껴지는가"의 근사치.
- 앱 상단 "로그" 시트 → 공유 버튼으로 전체 로그를 텍스트로 뽑는다. 결과마다 `확정/임시`, 오디오 구간, 지연, 커서, 정규화 거리, 전사 텍스트가 찍힌다.

## 4. Mac 사전 검증 (TTS 오디오, 2026-09-21)

실기기 전에 macOS 26.6.2(Apple Silicon)에서 `say -v Yuna`로 만든 오디오를 실시간 속도로 넣어 돌렸다.
TTS는 발음이 깨끗하고 잡음이 없으므로 **상한선**이다. 사람 목소리 결과는 5절에서 따로 본다.

### 4.1 ko-KR 지원·모델

- `SpeechTranscriber.supportedLocale(equivalentTo: ko-KR)` → `ko_KR` 반환. `AssetInventory.status` 처음엔 `.supported`, `downloadAndInstall()` 후 `.installed`. 이후 실행에서는 다운로드 없음.
- 파일 22050Hz → `bestAvailableAudioFormat` 16000Hz 1ch. `AVAudioConverter` 변환 경로로 정상 전사.

### 4.2 결정적 발견: `.fastResults` 없이는 실시간이 아니다

| 설정 | 임시 결과 도착 패턴 |
|---|---|
| `[.volatileResults]`만 | **~11.5초 단위로 묶여서** 도착 (11.6s에 80개, 23.1s에 55개, 30.8s에 51개). 인식은 증분으로 됐지만 전달이 묶임 |
| `[.volatileResults, .fastResults]` | **~0.93초 주기**로 꾸준히 도착. 주기는 투입 청크 크기(1024/4096/16384 프레임)와 무관 → 분석기 고유 주기 |
| `Options(priority: .userInteractive)` | 효과 없음. `fastResults`와 같이 주면 오히려 묶임 패턴으로 되돌아감 |

→ 낭독 추적에는 `.fastResults` 필수. 정확도 손실 여부는 실기기에서 확인(TTS에서는 확정 텍스트 동일).

### 4.3 결과 구조

- 임시 결과 = **미확정 구간 전체 텍스트(교체)**. 30초 낭독이 문장 경계에서도 확정되지 않고 임시 구간 하나로 자라다가 끝에 1번 확정됐다. → 매칭은 "자라는 텍스트"를 매번 앵커부터 다시 정렬해야 하고, 실제로 그렇게 동작한다.
- `audioTimeRange`: 임시 결과는 **run 1개(구간 전체)**. 어절별 시각은 확정 직전 마지막 패스에서만 나온다. → 실시간 하이라이트에 타이밍은 못 쓴다. 텍스트 정렬이 맞다.
- 첫 결과까지 걸린 시간: `fastResults` 켜면 ~1초.

### 4.4 3종 대본 결과 (`--fast`)

| 대본 | 커서 | 결과 수 | 오인식 |
|---|---|---|---|
| ① 일상 (60어절, 30.7s) | **60/60** | 200 | 빵집→방집, 갓→카스, 주전자에→주전자의, 읽다 만→입담한. 자모 정렬이 전부 흡수(거리 ≤ 0.05) |
| ② 빠르게 (52어절, 17.7s, TTS 속도 260) | **52/52** | 162 | 십 분→**10분**(숫자화), 괜히 든든하다→된 뒤 든하다. 흡수됨 |
| ③ 음독·음차 (28어절, 18.9s) | **17/28** | 67 | 사자성어풍(천지현명 …)은 8/8 추적. 만든 음절열은 일부 탈락(바니라 토로사 나비카 → 라 토로 나). **"일이삼사 오륙칠팔 구십백천"→"34678"**(숫자로 변환), "가나다라 마바사아…"는 전사 자체가 없음 |

- **대본 힌트(`AnalysisContext.contextualStrings`)는 효과 0.** `setContext`, 초기화 인자 두 경로 모두 결과가 바이트 단위로 동일. ko-KR 모델이 지원하지 않는 것으로 보인다(실기기 교차 확인).
- 숫자: 모델이 "십 분"→"10분", "일이삼사"→"34678"로 바꾼다. MVP 정규화에 **아라비아 숫자→한글 읽기 변환**을 넣어야 한다.

### 4.5 매칭 로직 관찰

- 임계값 0.45에서 오탐(엉뚱한 어절로 점프) 없음. 정상 매칭의 거리는 대부분 0.00~0.15.
- 어절이 절반만 발화된 상태("창ㅁ")에서는 이전 어절에 머문다(테스트 `partialLastWordDoesNotOvershoot`).
- 임시 텍스트가 무한히 자라므로 DP 비용이 O(발화 길이 × 탐색 범위)로 커진다. 30초/60어절에서는 문제 없었지만 MVP에서는 **안정된 접두어(마지막 N어절 앞)는 앵커를 당겨 잘라내는** 최적화가 필요하다.

## 5. 테스트 결과 (실기기)

**기기**: iPhone 15 Pro, iOS 26.7 / 2026-09-22~23 / Marco가 직접 낭독, 에이전트가 빌드·설치·콘솔 수집.
(원래 대상이던 iPhone 12 Pro는 iOS 18이라 제외. `SpeechAnalyzer`는 iOS 26+ 전용.)

### 5.1 환경 확인

- `SpeechTranscriber.isAvailable == true`. 지원 로케일 30개에 `ko_KR` 포함, 모델 설치됨.
- `DictationTranscriber` 지원 로케일은 54개로 더 넓다(`ko_KR` 포함).
- **포맷 함정 실제 확인**: 입력 `48000Hz 1ch Float32` ≠ 분석기 `16000Hz 1ch Int16 interleaved`. `AVAudioConverter` 변환 경로로 정상 동작.
- **`AVAudioSession` 함정**: `.record` + `.spokenAudio` 조합이 `OSStatus -50`(paramErr)으로 거부된다. `.playAndRecord` + `.spokenAudio`로 해결. Mac 하네스는 세션을 쓰지 않아 여기서만 드러났다.

### 5.2 ① 일상 문장

- **커서 60/60 완주.** 확정 결과 지연 0.15~1.12초.
- 오인식: 빵집→방집, 갓 구운→가고운/갖고 온, 첫 장→전장/첫 창, 울렸고→올렸고, 읽다 만→일다만/있다만, 페달→배달, 주전자에→주전자의.
  **전부 자모 정렬이 흡수**했고 커서는 정상 진행(거리 0.00~0.07).

### 5.3 ② 빠르고 작은 목소리 / ③ 음독·음차

- ②: 확정 지연 0.15~1.12초, 커서 27까지 확인. "십 분"→"10분" 숫자 변환.
- ③: "전지현명"(천지현명), "1월 성진"(일월성진), "풍철 월백"(풍청월백) 등 음이 비슷한 오인식. 자모 정렬로 커서는 진행(거리 0.01~0.08).

### 5.4 대본 밖 발화 — 오탐 없음

Marco가 대본을 벗어나 한국어·영어를 섞어 자유 발화한 구간(약 40초, "I'm your father", "I can understand what I speak" 등):

- **전사 자체는 정확**했다. 한·영 혼용을 그대로 받아 적는다.
- **커서는 33에 그대로 멈춰 있었다.** 임계값 0.45가 대본과 무관한 발화를 전부 걸러냈다. 되돌아가거나 엉뚱한 곳으로 튀는 오탐 0건.
- 다시 대본으로 돌아오자("동생은 주말에 같이 산에 가자고 했다") 커서가 44로 따라붙었다.

→ 매칭 로직의 **앞으로만 + 앵커 이후 탐색 + 임계값** 설계가 실제 사용 조건에서 의도대로 동작한다.

### 5.5 중간부터 읽기 시작 — 문제 발견 → 수정

대본 6번째 어절("공기를")부터 읽기 시작하자 **커서가 0에 14어절 동안 머물렀다.** 앵커(0) 바로 다음 어절과만 비교하므로 시작 지점을 못 찾은 것이다.

수정: `CursorMatcher`가 앵커 이후 **최대 6어절까지 건너뛴 시작점**도 후보로 본다. 동률이면 건너뛰지 않는 쪽을 택하고(`skipPenalty` 0.05), 건너뛰어도 임계값은 그대로 적용해 오탐을 막는다. 테스트 4개 추가(총 28개 통과).
TTS 재현으로 확인: 같은 조건에서 **두 번째 갱신(1.9초)에 커서 7**로 따라붙는다. _단, 이 수정은 아직 실기기에서 재확인하지 않았다(기기 연결 해제)._

### 5.6 DictationTranscriber 비교 (실기기)

- 결과 수가 눈에 띄게 적고, 확정 지연이 최대 2.49초까지 늘었다.
- 전사 품질은 비슷하거나 약간 낮다("갖고온 빵", "골목길 빵집").
- **실기기에서는 `SpeechTranscriber`(기본)가 낫다.** `DictationTranscriber`는 `SpeechTranscriber.isAvailable == false`인 기기용 폴백으로만 둔다.

### 5.7 Marco 총평

> "제일 기본으로 두고 처리하는 건 아주 잘 따라오는 것 같다. 영어랑 한글 섞어도 아래 생성되는 문자가 정확하게 받아들이고, 가끔 딜레이가 있긴 한데 텍스트 팔로잉도 잘 되는 것 같다."

## 6. 결론

### 지연 체감

| 측정 | 값 |
|---|---|
| 임시 결과 갱신 주기 | ~0.9초 (Mac TTS 기준, `.fastResults` 켰을 때) |
| 확정 결과 지연 (실기기 28건) | 평균 0.61초 · 중앙값 0.56초 · 최대 2.49초(받아쓰기 모델 포함) |
| 커서 진행 | 갱신 1회에 1~3어절 |

**"자막처럼 느껴지는가"에 대한 답: 그렇다. 다만 체감 지연이 있다.**
원인은 STT 자체가 아니라 파이프라인 전체의 누적이다 — 오디오 버퍼 → 인식 → 텍스트 정렬 → UI 갱신. `.fastResults`를 끄면 임시 결과가 **11초 단위로 묶여** 와서 낭독 추적이 불가능하다. 이 옵션이 이 앱의 전제 조건이다.

### 오인식 패턴

1. **음이 비슷한 치환** (빵집→방집, 울렸고→올렸고, 페달→배달): 자모 편집거리가 전부 흡수. 별도 처리 불필요.
2. **띄어쓰기 불일치** (갓 구운→가고운, 읽다 만→일다만): 자모 스트림 정렬이라 애초에 영향 없음.
3. **숫자 변환** (십 분→10분, 일이삼사→34678): 흡수 안 됨. **MVP 정규화에 아라비아 숫자 → 한글 읽기 변환이 필요하다.**
4. **대본 밖 발화**: 임계값이 걸러냄. 오탐 0건.

### 하이라이트 단위 권고 — **어절**

- 임시 결과가 ~0.9초마다 오고 그때마다 커서가 1~3어절 전진한다. 어절 단위 갱신이 실제로 가능하다.
- 문장 단위로 하면 긴 문장에서 10초 넘게 하이라이트가 안 움직여 "멈춘 것처럼" 보인다. ① 대본의 확정 구간이 9~14초였다.
- 어르신 사용자 전제에서는 어절 하이라이트 + **현재 줄 배경 강조**를 같이 주는 편이 위치를 놓치지 않는다. (2단계 디자인에서 결정)

### 체감 지연에 대한 장기 개선 방향 (MVP 범위 아님, Marco와 합의 필요)

- **다음 어절 강조(프롬프터 방식)**: 방금 읽은 어절 대신 다음에 읽을 어절을 강조하면 지연이 상쇄된다. 토글을 앱에 넣어 뒀으나 실기기 A/B는 미완.
- 하이라이트 이동에 짧은 애니메이션을 줘 "튀는" 느낌을 줄이기.
- 오디오 버퍼 크기 조정은 효과 없음(Mac 검증에서 청크 1024/4096/16384가 갱신 주기에 영향 없음 — 주기는 분석기 고유).

### MVP 구현에 넘길 것

1. `ScriptTracker` 패키지 **그대로 이관**(스파이크 중 유일하게 버리지 않는 코드). UI·STT 비의존, 테스트 28개.
2. `.fastResults` 필수. `attributeOptions: [.audioTimeRange]`는 실시간 하이라이트엔 못 쓴다(임시 결과는 run 1개) — 넣되 의존하지 않기.
3. `AVAudioSession`은 `.playAndRecord` + `.spokenAudio`.
4. `AVAudioConverter` 변환 경로 필수(48kHz Float32 → 16kHz Int16).
5. 정규화에 **숫자 → 한글 읽기 변환** 추가.
6. `SpeechTranscriber.isAvailable == false` 기기용 `DictationTranscriber` 폴백 유지.
7. 임계값 0.45, 건너뛰기 6어절이 실사용 기본값으로 적절(실기기 오탐 0건). 설정 노출은 불필요.
8. 수동 넘김 폴백은 실제로 쓰였다(중간 시작·인식 실패 시). MVP 필수.

### 미완 항목

- 건너뛰기 수정의 실기기 재확인
- "다음 어절 강조" 실기기 A/B
- `AnalysisContext.contextualStrings`: Mac에서 `SpeechTranscriber`는 무시, `DictationTranscriber`는 유효(음차 대본 17/28 → 28/28). 실기기 교차 확인 미완. MVP에서 신형 모델을 쓰므로 당장은 무의미.

## 7. Android 온디바이스 스파이크 (Issue #12, 2026-10-26)

> Android 검증 앱은 `spikes/android_stt/`에 있다. Flutter `MethodChannel`/`EventChannel`로 API 33+ 네이티브 `SpeechRecognizer`의 상태와 부분·최종 결과를 관찰하는 일회성 코드다. Issue #23의 제품 브리지 설계를 확정하지 않는다.

### 7.1 공식 API 계약

- `SpeechRecognizer.isOnDeviceRecognitionAvailable`을 먼저 확인하고, 참일 때만 `createOnDeviceSpeechRecognizer`를 사용한다. 일반 `createSpeechRecognizer` 폴백은 네트워크 사용 가능성을 만들기 때문에 스파이크에 넣지 않았다.
- 인식 요청은 `ko-KR`, `LANGUAGE_MODEL_FREE_FORM`, `EXTRA_PARTIAL_RESULTS`, `EXTRA_PREFER_OFFLINE`을 지정한다. 다만 Android 공식 문서상 부분 결과와 오프라인 선호 extra는 인식 서비스가 무시할 수 있으므로, 실제 기기·비행기 모드 검증이 별도로 필요하다.
- API 33의 `checkRecognitionSupport`로 설치·대기·지원 언어를 구분하고 `triggerModelDownload`로 모델 설치를 요청한다.
- `onPartialResults`는 한 세션에 0회 이상 올 수 있고, `onResults` 또는 `onError`가 올 때까지 다음 세션을 시작하지 않는다.
- 화면이 백그라운드로 가면 Dart에서 `cancel`, Activity 종료 시 네이티브에서 `cancel`과 `destroy`를 호출한다. 오디오 버퍼와 전사문은 저장하거나 외부로 보내지 않는다.

참조: Android Developers의 `SpeechRecognizer`, `RecognizerIntent`, `RecognitionListener` API 문서(2026-10-26 확인).

### 7.2 에뮬레이터 사전 검증

| 항목 | 결과 |
|---|---|
| 환경 | Android Emulator `sdk_gphone64_arm64`, API 36, Google Play 이미지 |
| 온디바이스 서비스 | `isOnDeviceRecognitionAvailable == true` |
| 인식 서비스 | Google TTS `GoogleTTSRecognitionService` |
| `ko-KR` 지원 | `supportedOnDeviceLanguages`에 포함 |
| 모델 상태 | 최초 미설치. 앱에서 37.57MB 한국어 업데이트 승인 후 `installedOnDeviceLanguages == [ko-KR]` 및 `ModelDownloadListener.onSuccess` 확인 |
| 비행기 모드 | 네트워크를 끈 상태에서도 `onReadyForSpeech` 도달. 설치 모델로 온디바이스 세션이 시작됨 |
| 시작 결과 | 모델 미설치 상태에서는 `ERROR_LANGUAGE_UNAVAILABLE(13)`, 설치 후 무음에서는 `ERROR_NO_MATCH(7)` 반환 |
| 마이크 입력 | Emulator Extended Controls의 `Enable Host Microphone Access` 활성화 확인 |
| UI | 앱 실행, 지원·다운로드 진행 상태, 권한, 준비·오류 이벤트의 Flutter 전달 확인 |

첫 부팅에서 System UI ANR이 반복됐으나 AVD 재부팅 뒤 앱 화면은 정상 렌더링됐다. 이는 인식 앱 프로세스의 crash가 아니며, 에뮬레이터만으로 한국어 마이크 품질을 판단하지 않는다.

호스트의 기본 입출력이 AirPods로 분리된 상태라 macOS TTS의 소리가 호스트 마이크에 들어가지 않았다. Emulator gRPC `injectAudio`로 직접 작성한 한국어 TTS PCM도 주입했으나 Google 온디바이스 인식 서비스는 `ERROR_NO_MATCH`를 반환했다.

호스트 마이크 경로는 `onRmsChanged`가 -2.0~3.8dB로 변하고 `onBeginningOfSpeech`/`onEndOfSpeech`가 발생해 오디오 전달 자체는 확인했다. 하지만 같은 세션에서 부분·최종 텍스트 없이 `ERROR_NO_MATCH`로 끝났다. 따라서 이 AVD에서는 모델 설치·오프라인 세션·오디오 생명주기까지 검증됐지만 **한국어 전사 품질과 부분 결과 발생 여부는 판정할 수 없다.**

### 7.3 결정과 QA 인계

API 33+ 제품 구현은 Android 시스템 온디바이스 `SpeechRecognizer`를 **조건부 채택**한다. AVD에서 한국어 모델 설치, 비행기 모드 세션 시작, 마이크 오디오 유입, 취소·종료 생명주기가 확인됐으므로 현재 단계에서 Vosk 다운로드형 모델을 추가 비교하지 않는다.

다만 AVD에서는 실제 한국어 전사와 부분 결과가 나오지 않았으므로 아래 항목은 시스템 STT의 출시 적합성을 확정하는 Issue #36의 실기기 QA로 넘긴다.

- Pixel과 Samsung API 33+에서 `ko-KR` 모델 설치 상태 확인
- 비행기 모드에서 부분·최종 결과와 네트워크 오류 부재 확인
- 중간 침묵, 빠른 목소리, 작은 목소리, 5분 이상 연속 낭독
- 부분 결과 주기·최종 지연·메모리·배터리와 제조사별 오류/재시작 계약 비교

Issue #36에서 시스템 STT가 낭독 추적 기준을 충족하지 못하는 경우에만 Vosk 등 다운로드형 모델 비교를 새 작업으로 분리한다.
