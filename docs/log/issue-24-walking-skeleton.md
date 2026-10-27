# Issue #24 Walking Skeleton 검증

## 구현 결과

- Flutter 3.47.7 / Dart 3.13.5 기준의 `maltto` 앱을 루트에 생성했다.
- `ScriptListView → ScriptListViewModel → ScriptRepository → ScriptService` 경계를 연결하고 구체 구현 조립은 `app/dependencies.dart`에 한정했다.
- iOS deployment target 26.0, Android minSdk 33 / compileSdk 36 / targetSdk 36, 양 플랫폼 식별자 `com.marcorable.maltto`를 적용했다.
- PR과 `develop`에서 분석·Dart/Flutter 테스트·Android Debug·서명 없는 iOS Simulator Debug 빌드를 실행하는 CI를 추가했다.
- 실제 배포 서명은 별도 보호 단계로 분리하고 인증 자료를 저장소에 넣지 않는 기준을 `docs/deployment.md`에 기록했다.

## 로컬 검증 환경

- macOS, Apple silicon
- Flutter 3.47.7 stable / Dart 3.13.5
- Xcode 26.2
- Android Emulator API 36 (`Medium_Phone_API_36`)
- iOS 26.3 Simulator (`iPhone 17 Pro`)

## 실행 결과

| 검증 | 명령 | 결과 |
|---|---|---|
| Public 저장소 정책 | `./scripts/check_public_repo.sh` | 통과 |
| 포맷 | `dart format --output=none --set-exit-if-changed .` | 변경 0건 |
| 정적 분석 | `flutter analyze` | 문제 0건 |
| 순수 Dart 테스트 | `dart test test/unit` | 1건 통과 |
| Flutter 테스트 | `flutter test` | 2건 통과 |
| Android Debug | `flutter build apk --debug` | 성공 |
| iOS Simulator Debug | `flutter build ios --simulator --debug --no-codesign` | 성공 |
| Android 실행 | API 36 Emulator에 APK 설치·실행 | 성공 |
| iOS 실행 | iOS 26.3 Simulator에 앱 설치·실행 | 성공 |

Android Emulator 최초 부팅 중 System UI 응답 지연 안내가 한 번 나타났다. 부팅 완료 상태를 확인하고 안내를 닫은 뒤 앱을 재실행해 정상 화면을 다시 캡처했다. 재발 방지를 위해 캡처 스크립트가 Android 부팅 완료와 boot animation 종료를 확인하도록 보강했다.

## 화면 확인

| 플랫폼 | 기본 글씨 | 큰 글씨 |
|---|---|---|
| Android | ![Android 기본 글씨](images/issue-24/android-default.png) | ![Android 큰 글씨](images/issue-24/android-large-text.png) |
| iOS | ![iOS 기본 글씨](images/issue-24/ios-default.png) | ![iOS 큰 글씨](images/issue-24/ios-large-text.png) |

양 플랫폼에서 Cupertino 기반 빈 대본 화면이 표시됐고, 큰 글씨에서도 제목과 빈 상태 문구가 잘리거나 겹치지 않았다. 화면에는 기본 탑재 대본이나 제3자 텍스트가 없다.

## CI와 배포 경계

CI workflow 파일은 로컬에서 구성과 명령을 검증했지만, 이 작업에서는 push를 하지 않았으므로 GitHub-hosted runner의 실제 실행 결과는 아직 없다. PR을 열기 전에 사용자 확인을 받고 push한 뒤 세 job의 통과를 확인해야 한다. TestFlight와 스토어 업로드는 이 Issue 범위가 아니며 배포 시크릿도 만들거나 읽지 않았다.
