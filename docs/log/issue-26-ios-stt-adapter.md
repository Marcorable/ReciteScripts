# Issue #26 iOS SpeechAnalyzer STT 어댑터

검증일: 2026-10-27

## 구현 범위

- `pigeons/stt_api.dart`를 단일 전송 계약으로 두고 Pigeon 29.0.11로 Dart/Swift 코드를 생성했다.
- 공개 Dart 계약(`SttService`, `SttAvailability`, `SttPreparation`, `SttEvent`)과 생성 타입을 `PigeonSttService`에서 분리했다.
- iOS 26+ `SpeechAnalyzer` + `SpeechTranscriber`의 온디바이스 `ko-KR` 지원과 `AssetInventory` 설치 상태를 확인하고, `prepare`에서 필요한 모델 설치를 수행한다.
- 마이크와 음성 인식 권한을 각각 확인한다. 권한이 없으면 오디오 세션을 시작하지 않는다.
- `AVAudioEngine` 입력 포맷과 `bestAvailableAudioFormat`이 다르면 `AVAudioConverter`로 변환한다. 변환기를 만들 수 없으면 `audioFormatMismatch`로 시작을 거부한다.
- volatile/final 결과와 ready/ended/failure/cancelled를 session ID, generation, 단조 증가 sequence와 함께 전달한다.
- 취소·dispose·백그라운드 전환 시 이벤트 발행을 차단하고 audio tap, 입력 stream, 결과 Task, analyzer, audio session을 정리한다.
- 시작 예약을 첫 비동기 작업 전에 잡고 각 비동기 경계 뒤에 취소 여부를 다시 확인해, 준비 중 cancel과 동시 start가 마이크를 고아 상태로 남기지 않게 한다.
- 전화·Siri 등 오디오 interruption과 media-services reset은 재시도 가능한 `interrupted` failure로 세션을 종료한다.
- 실행 중 오디오 변환 실패는 정상 `ended`가 아니라 재시도 불가능한 `audioFormatMismatch` failure로 전달한다.
- 종료된 generation, 중복 sequence, 빈 부분/최종 전사는 Dart 경계에서 폐기한다.
- 원시 오디오와 RMS는 Dart로 전달하지 않고, 오디오 파일을 만들거나 네트워크로 전송하지 않는다.

Apple 문서상 `SpeechAnalyzer`의 transcriber는 음성을 Apple 서버로 전송하지 않는다. 모델 자산은 `AssetInventory`가 시스템 범위에서 관리한다.

- <https://developer.apple.com/documentation/speech/speechanalyzer>
- <https://developer.apple.com/documentation/speech/assetinventory>
- <https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition>
- <https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)>

## 자동 검증

| 항목 | 결과 |
|---|---|
| Dart 구조화 계약 | 권한 거부, 모델 미설치, 오디오 포맷 불일치 failure 매핑 테스트 통과 |
| Dart 시작 오류 | Pigeon `PlatformException`을 플랫폼 중립 `SttStartException`으로 변환하는 테스트 통과 |
| generation 방어 | cancel 뒤 도착한 이전 generation 결과와 빈 전사 폐기 테스트 통과 |
| iOS XCTest | iPhone 17 Pro / iOS 26.3.1 대상 `xcodebuild test` 통과 |
| iOS SDK 컴파일 | Xcode 26.2 / iOS Simulator SDK 26.2에서 Debug 빌드 통과 |
| 시뮬레이터 실행 | iPhone 17 Pro / iOS 26.3.1에서 설치·실행 및 기존 화면 렌더링 확인 |

시뮬레이터 실행 화면: [ios-simulator.png](images/issue-26/ios-simulator.png)

## 실기기 검증 상태와 절차

`xcdevice`에서 물리 iPhone 12 Pro(iOS 18.7.8)가 보였지만 연결 가능 상태가 아니며, 최소 지원 버전 iOS 26도 충족하지 않는다. 따라서 **실기기 오프라인 `ko-KR` 부분/최종 결과는 검증하지 않았고 성공으로 판정하지 않는다.**

iOS 26+ 실기기가 준비되면 다음을 확인해야 한다.

1. 앱을 새로 설치하고 마이크·음성 인식 권한의 허용/거부 상태가 각각 구조화 상태로 전달되는지 확인한다.
2. `ko-KR` 모델이 없는 상태에서 `modelDownloadRequired` 또는 설치 진행 상태가 표시되고, 설치 뒤 `ready`가 되는지 확인한다.
3. 네트워크를 끈 상태에서 직접 작성한 더미 문장을 읽고 non-final 결과가 `partial`, 확정 결과가 `finalResult`로 같은 generation에 도착하는지 확인한다.
4. 입력 포맷과 analyzer 포맷이 다른 기기에서 변환 후 결과가 나오며, 변환 불가 시 `audioFormatMismatch`로 종료되는지 확인한다.
5. 낭독 중 홈 화면으로 이동했을 때 마이크 표시가 사라지고 `cancelled` 뒤 늦은 결과가 전달되지 않는지 확인한다.
6. 취소 직후 generation을 증가시켜 재시작하고 이전 generation 결과가 새 소비자에게 전달되지 않는지 확인한다.

실기기 검증 중 전사문이나 음성은 로그·파일·분석 도구에 남기지 않는다.
