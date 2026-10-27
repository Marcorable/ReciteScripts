# 말또

사용자가 직접 입력한 대본을 반복해서 낭독하도록 돕는 Flutter 앱이다. 사용자 텍스트와 음성은 기기 밖으로 보내지 않는다.

## 로컬 검증

Flutter 3.47.7과 Dart 3.13.5를 기준으로 한다.

```bash
flutter pub get
./scripts/check_public_repo.sh
./scripts/test.sh
./scripts/build.sh
```

실행 중인 Android Emulator와 iOS Simulator에서 화면을 확인하고 스크린샷을 저장한다.

```bash
./scripts/screenshot.sh android
./scripts/screenshot.sh ios
```

서명 없는 검증과 실제 배포 절차는 [`docs/deployment.md`](docs/deployment.md)에 분리해 두었다.
