# Issue #30 낭독 화면

## 구현

- `ReadingSessionState`가 토큰화된 전체 어절을 제공하고, View는 세션 상태를
  완료·현재·대기 어절로만 렌더링한다. 대본 영역에는 전진 탭·버튼을 두지 않았다.
- 현재 어절은 indigo 캡슐, 완료 어절은 굵은 indigo 글자, 대기 어절은
  secondary label로 표시해 색 외에도 모양과 굵기로 구분한다.
- 현재 어절이 화면 밖에 있을 때만 자동 스크롤한다. 순방향은 화면 아래쪽의
  읽기 가능한 위치, 후퇴는 화면 위쪽의 읽기 가능한 위치로 이동한다.
  `MediaQuery.disableAnimations` 또는 iOS Reduce Motion이 켜져 있으면 즉시
  이동하고 상태 전환 애니메이션도 제거한다.
- 반복은 2회 이상일 때만 `현재/전체 · 남은 횟수`를 표시한다. 경과 시간은
  세션이 소유한 단조 증가 값을 `MM:SS` 또는 `HH:MM:SS`로 표시한다.
- 한 어절 뒤로는 Domain에서 커서를 정확히 하나 줄이고 generation을 올린 뒤
  이전 STT를 취소하고 새 generation을 시작한다. 첫 어절에서는 상태·STT 작업을
  바꾸지 않으며 비활성 이유를 Semantics로 알린다.
- 진행된 세션의 나가기는 진행 폐기 확인을 제공한다. 첫 어절, 완료·종료 상태는
  불필요한 확인 없이 처리한다. 종료는 상태와 generation을 먼저 바꾸고 timer,
  STT 작업, Dart 구독을 정리한 뒤 목록으로 돌아간다.
- 최종 어절 완료는 같은 화면의 완료 상태로 전환하고 최종 경과 시간과 명시적인
  `목록으로` 동선을 제공한다.
- 어절 상태, 현재/전체 회차, 진행 어절 수, 경과 시간, 후퇴·나가기·완료 조작에
  VoiceOver/TalkBack 라벨을 제공한다. 실제 Android 접근성 트리에서 외부
  `Semantics`가 자식 버튼의 탭 액션을 가리던 문제를 발견해 명시적인 Semantics
  탭 액션을 연결했다.

## 자동 검증

- `dart format --output=none --set-exit-if-changed .`: 통과
- `flutter analyze`: 통과
- `flutter test`: 84개 통과
  - 완료·현재·대기 렌더링과 Repository 상태에 의한 전진
  - 대본 탭으로 전진하지 않음
  - 자동 스크롤과 Reduce Motion의 즉시 이동
  - 1회/여러 회 회차 표시, 경과 시간
  - 한 어절 후퇴, 첫 어절 경계, 후퇴 전 generation의 늦은 결과 폐기
  - 나가기 확인·취소·종료, 최종 완료와 늦은 실행 상태 무시
  - 완료·나가기 뒤 STT 취소, subscription·timer 종료
  - Accessibility XL 최소 터치 영역과 Semantics 탭 액션
- `flutter build apk --debug`: 통과
- `DEVELOPER_DIR=/Applications/Xcode-26.2.0.app/Contents/Developer flutter build ios --simulator --debug --no-codesign`: 통과

Xcode 27.2 / Swift 6.4.2의 기본 빌드는 Issue #29와 동일하게 기존
`IosSpeechSession.swift`의 `AVAudioConverter.convert` 호출에서
`Copy of noncopyable typed value` 컴파일러 내부 오류가 발생했다. 저장소의 기존
STT 구현을 바꾸지 않고, 이전 검증과 같은 Xcode 26.2로 iOS 빌드와 실행을
완료했다.

## 실제 실행과 화면 확인

제품 `ReadingView`에 로컬 프리뷰 세션 상태를 주입한 임시 엔트리로 실행한 뒤
임시 파일은 삭제했다. 스크린샷에는 직접 작성한 중립적 더미 문장만 사용했다.

- iOS 26.3 iPhone 17 Pro Simulator
  - [기본 글씨](images/issue-30/ios-default.png)
  - [Accessibility XL](images/issue-30/ios-accessibility-xl.png)
- Android API 36 Emulator
  - [기본 글씨](images/issue-30/android-default.png)
  - [Accessibility XL](images/issue-30/android-accessibility-xl.png)

양 플랫폼에서 여러 줄 대본의 완료·현재·대기 표현, 2/3회 상태, 경과 시간,
현재 어절 가시성, 하단 후퇴·나가기 조작을 확인했다. Accessibility XL에서도
현재 어절과 두 조작이 화면 안에 남고 대본 영역이 스크롤 가능했다. iOS
접근성 트리에는 모든 어절 상태와 회차·경과 시간·컨트롤 이름이 노출됐다.
Android UIAutomator 트리에서는 후퇴·나가기 버튼이 각각 48dp 이상이고 수정 후
`clickable=true`인 것을 확인했다. 양 플랫폼에서 후퇴를 실제 조작해 진행 어절
수가 8에서 7로 줄고 현재 어절이 정확히 하나 이전으로 바뀌는 것도 확인했으며,
진행된 상태의 나가기 확인 문구와 두 선택지를 확인했다.

## 음성 전체 흐름의 확인 범위

- iOS 26.3 Simulator의 제품 앱은 준비 단계에서 온디바이스 한국어 음성 인식을
  지원하지 않는다고 반환해 낭독 화면에 진입하지 못했다.
- Android API 36 Emulator의 제품 앱은 온디바이스 준비와 낭독 화면 진입,
  첫 어절 표시, 경과 시간 갱신까지 성공했다. 약 5초 뒤 Emulator의 가상 오디오
  입력이 `Initialization failed`를 반환해 실제 음성 전진은 확인하지 못했다.
- 따라서 양 플랫폼 실기기에서 직접 작성한 한국어 대본을 음성으로 끝까지 읽는
  검증, VoiceOver/TalkBack의 실제 음성 읽기 순서, 시스템 Reduce Motion을 켠
  상태의 체감 확인은 남은 실기기 검증이다. Simulator/Emulator 결과를 음성
  전체 흐름 성공으로 간주하지 않는다.

## 자원 종료 근거

Repository 테스트는 완료·나가기에서 상태와 generation을 먼저 바꾸고 timer를
중단한 뒤 네이티브 `cancel`과 Dart 구독 취소를 수행하는 순서를 검증한다.
네이티브 취소 완료 전에 이전 generation의 STT 이벤트를 보내도 커서·회차·완료
상태가 바뀌지 않으며, 완료 뒤 timer tick도 최종 경과 시간을 바꾸지 않는다.
