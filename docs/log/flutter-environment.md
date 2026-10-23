# Flutter 개발 환경 검증

검증일: 2026-10-23

## 결정

- Flutter는 production 앱에 권장되는 `stable` 채널을 사용한다.
- MVP 기준 버전은 Flutter `3.47.7`, Dart `3.13.5`다.
- Android Studio를 주 IDE로 사용하고 Xcode를 iOS 빌드·서명·배포에 병행한다.
- 제품의 최소 버전과 빌드 도구 버전을 분리한다.
  - iOS deployment target: 26.0
  - Android minSdk: 33
  - Android compileSdk / targetSdk: 36
- SDK를 중복 설치하지 않고 기존 Homebrew Flutter를 교체했다.

공식 근거:

- [Flutter SDK 설치](https://docs.flutter.dev/install/manual)
- [Flutter 업그레이드와 stable 채널](https://docs.flutter.dev/install/upgrade)
- [Flutter stable release notes](https://docs.flutter.dev/release/release-notes)
- [Android 개발 환경 설정](https://docs.flutter.dev/platform-integration/android/setup)
- [iOS 개발 환경 설정](https://docs.flutter.dev/platform-integration/ios/setup)

## 설치 상태

| 항목 | 버전·경로 |
|---|---|
| Flutter | 3.47.7 stable, `/opt/homebrew/share/flutter` |
| Dart | 3.13.5 |
| Android Studio | 2026.1, `/Users/marco/Applications/Android Studio.app` |
| Android SDK | Platform 36, minSdk 33 |
| Android Emulator | 36.2.12, `Medium_Phone_API_36` |
| Xcode | 26.2, `/Applications/Xcode-26.2.0.app` |
| iOS Simulator | iOS 26.3, iPhone 17 Pro |

대략적인 로컬 용량은 Flutter 3.5GB, Android Studio 3.2GB, Android SDK 7.3GB다.
기존 Flutter를 업그레이드해 SDK가 두 벌 남지 않게 했다.

## 검증 프로젝트

제품 구조를 확정하기 전이므로 `spikes/flutter_buildcheck`에서 환경만 검증했다.
화면은 Flutter `CupertinoApp`과 `CupertinoPageScaffold`로 구성했다.

```sh
cd spikes/flutter_buildcheck
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

## 결과

| 검증 | 결과 |
|---|---|
| Dart 포맷 | 통과 |
| Flutter 정적 분석 | 문제 0건 |
| Widget test | 1건 통과 |
| Android debug APK | 빌드 성공 |
| iOS Simulator app | 빌드 성공 |
| Android API 36 실행 | 성공 |
| iOS 26.3 Simulator 실행 | 성공 |

실행 화면:

- [Android](images/flutter-buildcheck-android.png)
- [iOS](images/flutter-buildcheck-ios.png)

## 남은 경고

`flutter doctor -v`의 필수 Android 도구와 일반 Android SDK 라이선스는 준비됐다.
남은 두 라이선스는 Android XR Preview와 microXR 시스템 이미지 전용이다. 이 앱은 XR SDK를
사용하지 않으므로 경고를 없애기 위한 목적으로 약관에 동의하지 않았다. Android APK 빌드와
에뮬레이터 실행에는 영향이 없다.

Gradle 첫 빌드에서 JDK의 native access 관련 향후 호환 경고가 출력됐지만 빌드는 성공했다.
제품 프로젝트를 만드는 Issue에서 Flutter가 선택한 Android Studio bundled JDK와 생성된 Gradle
버전의 공식 지원 조합을 다시 확인한다.

## marcorable-kit 후보

아래 항목은 이번 프로젝트에서 한 번 검증된 상태다. 제품 프로젝트와 CI에서도 재검증된 뒤
`marcorable-flutter` 팩의 규칙 또는 절차로 승격한다.

- production 프로젝트는 Flutter stable의 정확한 버전을 문서와 CI에 함께 고정한다.
- Android의 `minSdk`와 최신 Flutter가 요구하는 `compileSdk`를 별도 결정으로 관리한다.
- 앱과 무관한 선택형 SDK 라이선스를 단순히 doctor 경고를 없애기 위해 승인하지 않는다.
- Flutter 생성 직후 iOS 프로젝트에 로컬 Apple Team ID가 들어갔는지 검사하고 제거한다.
