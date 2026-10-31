# Android 온디바이스 STT 어댑터 검증 — Issue #27

> 2026-10-31. Android API 33+ 제품 어댑터 구현과 자동·기기 검증 결과다.

## 구현 범위

- `SpeechRecognizer.isOnDeviceRecognitionAvailable`이 참일 때만
  `createOnDeviceSpeechRecognizer`를 사용한다. 일반 인식기나 외부 STT SDK 폴백은 없다.
- `RECORD_AUDIO`, `ko-KR`의 `checkRecognitionSupport`, 설치·대기·다운로드 가능 모델 상태를
  플랫폼 중립 Pigeon 계약으로 변환한다.
- `prepare`는 모델 다운로드를 자동 시작하지 않는다. 호출자가
  `requestModelDownload`를 명시적으로 선택했을 때만 `triggerModelDownload`를 실행한다.
- recognizer 생성, 지원 확인, 시작, 취소, listener 해제, destroy는 Android main looper에서만
  실행한다. 지원 확인 콜백이 오지 않으면 10초 뒤 구조화된 미지원 상태로 종료한다. 연속된
  `checkAvailability` → `prepare` → `start`가 인식 서비스에 같은 조회를 몰아넣지 않도록 확인된
  설치 상태를 재사용한다.
- 세션 객체가 `sessionId`, `generation`, 단조 증가 `sequence`와 terminal 상태를 소유한다.
  terminal 또는 취소 뒤 콜백은 버리고, 백그라운드·Activity 종료 시 `cancel` 후 `destroy`한다.
- `onRmsChanged`와 `onBufferReceived`는 무시한다. 원시 오디오와 RMS를 Dart로 전달하거나
  파일로 저장하지 않는다.

## 자동 검증

실행한 명령은 다음과 같다.

```text
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
flutter build apk --debug
```

Android JVM 테스트는 다음을 검증한다.

- 권한 미결정·거부 상태
- `ko-KR` 설치·다운로드 대기·다운로드 가능·미지원 모델 상태
- 인식 서비스 오류의 공통 failure 변환과 retryable 여부
- ready → partial → final → ended 순서와 sequence
- 취소 이벤트, 빈 최종 결과, 취소 뒤 늦은 콜백 폐기

Dart 테스트는 명시적 모델 다운로드 상태, terminal 뒤 더 큰 generation 재시작, 이전 generation의
늦은 이벤트 폐기까지 검증한다. Android instrumentation smoke test는 실제 시스템 서비스에서
지원·준비 상태와 백그라운드 취소·해제를 확인한다.

## 에뮬레이터

| 항목 | 결과 |
|---|---|
| 환경 | `Medium_Phone_API_36`, Google Play arm64 이미지 |
| 권한 | 테스트 APK에 `RECORD_AUDIO`를 명시적으로 부여 |
| 지원 확인 | 첫 실행은 `checkRecognitionSupport` 콜백이 20초 안에 오지 않았고, 안정화 뒤 재실행에서는 `ko-KR == INSTALLED` 확인 |
| 제품 동작 | 콜백 미수신은 10초 상한 뒤 구조화된 미지원 상태로 종료. 안정화 뒤에는 `READY` |
| 생명주기 | 최종 instrumentation smoke test 2개 통과. 시작·백그라운드 전환·recognizer 파기 확인 |
| 앱 실행 | Debug APK 실행 및 빈 대본 화면 렌더링 확인 |
| 환경 이상 | 스파이크 때와 동일하게 첫 실행에서 System UI ANR이 발생했고 `Wait` 뒤 앱 화면은 정상 표시됨 |

초기 콜백 미수신을 지원 성공으로 기록하지 않았고, 이후 정상 응답과도 별도로 남겼다. 이 AVD에서는
모델 다운로드나 한국어 전사 품질을 재판정하지 않는다.

## 연결된 Samsung 실기기

| 항목 | 결과 |
|---|---|
| 기기 | Samsung `SM F776N`, Android 17/API 37 |
| 온디바이스 엔진 | 사용 가능 |
| `ko-KR` | 지원됨, 모델 설치 상태 `INSTALLED` |
| 준비 | `READY` |
| 백그라운드 | 시작 직후 백그라운드 전환 시 취소·파기 smoke test 통과 |
| 비행기 모드 | 온디바이스 세션 시작 후 한국어 `PARTIAL` 이벤트 수신 |

비행기 모드 테스트에는 직접 작성한 더미 문장의 시스템 TTS만 사용했다. 테스트는 전사문을
출력·저장하지 않고 이벤트 종류만 기록했다. 최초 시도는 Mac 출력 볼륨이 6%여서 `NO_MATCH`였고,
내장 스피커 75%에서 재시도해 `PARTIAL`을 확인했다. 기기 비행기 모드와 Mac 볼륨은 각각 원래의
꺼짐과 6%로 복원했다.

## Issue #36 인계

이번 실기기 검증은 연결돼 있던 Samsung 한 대의 짧은 발화만 다룬다. 출시 게이트에서는 다음을
추가 확인한다.

- Pixel API 33+와 다른 Samsung 모델의 `ko-KR` 설치·다운로드 흐름
- 부분 결과 수정, 최종 결과, 침묵·작은 목소리·빠른 목소리 오류 계약
- 취소·백그라운드·재진입·generation 교체를 반복했을 때 늦은 콜백 부재
- 비행기 모드에서 5분 이상 연속 낭독의 지연, 메모리, 배터리
- 제조사별 부분 결과 주기와 시스템 STT의 출시 적합성

시스템 STT가 위 기준을 충족하지 못한다는 새 근거가 생길 때만 외부 모델 비교를 별도 작업으로
분리한다.
