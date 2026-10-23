# 빌드·테스트 검증 루프

> AGENTS.md 8번 검증 루프의 실행 진입점. Issue #8에서 시작했고, Issue #10에서 Flutter 양 플랫폼 기준으로 전환했다.

## 현재 결론: Flutter CLI와 플랫폼 기본 도구를 사용한다

검증 스크립트는 Flutter 프로젝트 하나에서 Android와 iOS를 모두 확인한다. XcodeBuildMCP 같은 서드파티 MCP는 필수 의존성으로 두지 않는다.

- `flutter`와 `dart`로 포맷·분석·테스트·양 플랫폼 빌드를 실행한다.
- Android 스크린샷은 `adb`, iOS 스크린샷은 `xcrun simctl`을 사용한다.
- Claude와 Codex, 로컬과 CI가 같은 명령을 사용한다.
- 한 플랫폼만 성공하고 전체 검증이 통과한 것으로 보고하지 않는다.

## 명령

```bash
./scripts/test.sh                         # 포맷·정적 분석·유닛/위젯 테스트
./scripts/build.sh                        # Android APK + iOS Simulator 앱 빌드
./scripts/screenshot.sh android           # Android 기본 글자 크기
./scripts/screenshot.sh android large-text
./scripts/screenshot.sh ios               # iOS 기본 글자 크기
./scripts/screenshot.sh ios large-text
```

기본 대상은 `spikes/flutter_buildcheck`다. 다른 Flutter 프로젝트를 검증할 때는 절대 경로로 덮어쓴다.

```bash
FLUTTER_PROJECT=/absolute/path/to/app ./scripts/test.sh
FLUTTER_PROJECT=/absolute/path/to/app ./scripts/build.sh
```

- 스크린샷은 `.build/flutter-verification/screenshots/`에 저장한다.
- Android는 실행 중인 Emulator가 필요하다. 여러 대라면 `ANDROID_DEVICE_ID`를 지정한다.
- 다른 Android 앱을 검증할 때는 `ANDROID_APP_ID`도 함께 지정한다.
- iOS는 부팅된 iPhone Simulator가 필요하다. 여러 대라면 `IOS_SIMULATOR_UDID`를 지정한다.
- 스크립트는 필요한 기기나 빌드 산출물이 없으면 성공으로 넘기지 않고 종료 코드 1로 실패한다.

## 검증 대상: `spikes/flutter_buildcheck`

제품 구조를 확정하기 전 개발 환경과 검증 루프만 확인하는 최소 Flutter 앱이다. 실제 앱 골격은 Walking Skeleton Issue에서 만들고, Flutter 디렉터리 구조와 네이티브 STT 브리지 방식은 Issue #23에서 정한다.

- Flutter `CupertinoApp` 화면 하나
- Flutter widget test 1개
- Android API 33+ / compileSdk·targetSdk 36
- iOS deployment target 26.0

## 실행 결과 (2026-10-23)

| 단계 | 결과 |
|---|---|
| Dart 포맷 | 변경 0건 |
| Flutter 정적 분석 | 문제 0건 |
| Widget test | 1건 통과 |
| Android debug APK | 빌드 성공 |
| iOS Simulator debug 앱 | 빌드 성공 |
| Android Emulator 실행 | 성공, `docs/log/images/flutter-buildcheck-android.png` |
| iOS Simulator 실행 | 성공, `docs/log/images/flutter-buildcheck-ios.png` |

## 이전 Swift 전용 진입점 폐기

Issue #8에서 만든 `spikes/buildcheck/BuildCheck.xcodeproj`용 스크립트는 Flutter 전환 뒤 전체 검증 진입점으로 사용할 수 없다. iOS 전용 빌드가 성공해도 Flutter·Android 코드를 검증하지 않기 때문이다. `scripts/build.sh`, `scripts/test.sh`, `scripts/screenshot.sh`는 Issue #10부터 Flutter 양 플랫폼 기준으로 교체했다.
