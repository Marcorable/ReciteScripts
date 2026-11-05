# Issue #31 음성 인식 오류 복구와 접근성

## 구현

- 준비 단계의 음성 인식 상태와 실패를 권한 필요·권한 거부·모델 준비 중·
  온디바이스 미지원·오디오 충돌·인식 중단·일시 오류로 구분한다.
- 시작 직후 네이티브 STT가 실패해도 예외를 화면까지 노출하지 않고 구조화된
  준비 상태로 변환한다. 사용자는 원인에 맞춰 권한 허용, 설정 열기, 준비 상태
  확인 또는 다시 시도를 선택할 수 있다.
- Pigeon API에 `openAppSettings`를 추가했다. iOS는
  `UIApplication.openSettingsURLString`, Android는
  `Settings.ACTION_APPLICATION_DETAILS_SETTINGS`와 앱의 `package:` URI를 사용한다.
  Android에서는 설정 화면을 처리할 Activity가 있는지 먼저 확인한다.
- 낭독 중 비복구 STT 실패도 권한·모델·미지원·오디오·중단·알 수 없는 오류로
  보존한다. 현재 진행 데이터는 수동 전진 없이 종료 상태로 전환되고, 원인별
  안내와 명시적인 `목록으로` 동선을 제공한다.
- 오류 안내는 live region으로 노출하고, 설정·재시도·취소·목록 버튼의 최소
  높이를 48 logical pixel로 유지한다. 큰 글자에서는 화면 전체가 스크롤되어
  조작이 가려져도 접근할 수 있다.

공식 API 참고:

- [iOS `openSettingsURLString`](https://developer.apple.com/documentation/uikit/uiapplication/opensettingsurlstring)
- [Android `ACTION_APPLICATION_DETAILS_SETTINGS`](https://developer.android.com/reference/android/provider/Settings#ACTION_APPLICATION_DETAILS_SETTINGS)
- [Flutter `Semantics`](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
- [Flutter `liveRegion`](https://api.flutter.dev/flutter/semantics/SemanticsProperties/liveRegion.html)

## 자동 검증

- `dart format --output=none --set-exit-if-changed .`: 통과
- `flutter analyze`: 통과
- `flutter test`: 98개 통과
  - 시작 단계의 권한 거부·오디오 충돌 안내와 설정 열기
  - 시작 예외의 구조화된 준비 상태 변환
  - 앱 설정 열기 Pigeon 위임
  - 낭독 중 오디오 실패의 원인 보존, live region 안내, 안전한 목록 복귀
  - 설정 버튼의 48 logical pixel 최소 높이
- `./gradlew testDebugUnitTest`: 통과
- `xcodebuild test` (`iPhone 17 Pro`, iOS 26.3.1): 1개 통과
- `flutter build apk --debug`: 통과
- `flutter build ios --simulator --debug --no-codesign`: 통과
- `git diff --check`: 통과

## 실제 실행과 접근성 확인

- iOS 26.3 iPhone 17 Pro Simulator
  - 콘텐츠 크기: `accessibility-extra-extra-extra-large`
  - 마이크 권한을 거부한 뒤 원인 안내, 설정 열기, 다시 시도, 취소를 확인했다.
  - macOS 접근성 트리에서 오류 문구와 모든 조작 이름이 별도 접근성 요소로
    노출되는 것을 확인했다.
  - `설정 열기`를 누르면 시스템 설정으로 전환되는 것을 확인했다.
  - [권한 거부 · 접근성 최대 글자](images/issue-31/ios-permission-denied-accessibility-xxxl.png)
- Android API 36 Emulator
  - 시스템 `font_scale=2.0`으로 설정했다.
  - 실제 시스템 마이크 권한 요청에서 거부한 뒤 원인 안내, 설정 열기, 다시 시도,
    취소를 확인했다.
  - UIAutomator 트리에서 오류 안내와 모든 버튼이 노출되고, 설정·취소·재시도
    버튼이 최소 48dp보다 큰 것을 확인했다.
  - `설정 열기`가 말또의 App info 화면으로 이동하며 `No permissions granted`를
    표시하는 것을 확인했다.
  - [권한 거부 · 글자 배율 2.0](images/issue-31/android-permission-denied-font-scale-2.png)

두 플랫폼 모두 큰 글자에서 안내와 주요 복구 조작이 잘리지 않았고, 하단 조작은
스크롤로 접근할 수 있었다. 시뮬레이터·에뮬레이터 검증은 접근성 트리와 화면
레이아웃 확인 범위이며, VoiceOver/TalkBack의 실제 음성 읽기 순서는 실기기에서
별도로 확인해야 한다.

## 실패 후 자원과 데이터 보존

시작 실패는 생성된 STT 세션과 이벤트 구독을 정리한 뒤 준비 화면 상태로
복귀한다. 낭독 중 비복구 실패는 실패 종류를 세션 상태에 기록하면서 기존
generation을 무효화하고 종료 상태로 전환한다. 기존 대본과 진행 데이터는
삭제하지 않으며, 사용자가 명시적으로 목록으로 돌아갈 때까지 오류 안내를
유지한다.
