# Android 온디바이스 STT 스파이크

Issue #12에서 Android 13(API 33)+ `SpeechRecognizer`의 한국어 온디바이스 부분 결과를 검증하는 일회성 Flutter 앱이다.

- `createOnDeviceSpeechRecognizer`만 사용한다. 일반 인식기로 폴백하지 않는다.
- `ko-KR`, 부분 결과, 오프라인 선호를 명시한다.
- 마이크 오디오는 저장하거나 네트워크로 전송하지 않는다.
- 앱이 백그라운드로 가면 인식을 취소한다.

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter run -d <device-id>
```

화면의 `ko-KR 지원 확인`으로 설치·대기·지원 언어 목록을 확인하고, 비행기 모드에서 직접 작성한 문장을 읽어 부분 결과와 최종 결과를 기록한다.
