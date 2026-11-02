# Issue #29 낭독 시작 설정 및 반복 세션 상태

## 구현

- 대본 목록의 선택 동작을 Cupertino 낭독 시작 설정 화면에 연결했다.
- 반복 횟수는 1~10회에서 고르며 기본값은 1회다.
- 순수 Dart `ReadingSessionReducer`가 실행·완료·종료 상태, 현재/전체 회차,
  현재 어절, 경과 시간, STT generation과 마지막 sequence를 소유한다.
- `LocalReadingSessionRepository`가 `ReadingProgress`와 `SttService`를 조합하고,
  회차 경계의 네이티브 취소·재시작, 구독과 타이머 수명을 관리한다.
- 시작 준비 결과가 모델 설치 필요인 경우 `requestModelDownload`를 실행하고,
  준비 중·권한·미지원 상태를 시작 화면에 최소 안내한다.
- 회차 완료와 나가기에서 상태와 generation을 먼저 바꾼 뒤 비동기 자원을
  정리해 중복 partial/final과 늦은 이벤트를 폐기한다.
- 회차 도중 STT `ended`가 오면 현재 커서와 회차를 유지하고 generation을
  교체한 뒤 인식을 재시작한다.
- 복구 가능한 STT `failure`는 같은 위치에서 새 generation으로 재시작하고,
  복구할 수 없는 실패는 먼저 세션을 종료한 뒤 자원을 정리한다.
- 시작 준비 중 앱이 백그라운드로 가면 현재 시작 attempt를 무효화해 준비
  완료 후 마이크가 늤어서 시작되지 않게 한다.
- 최소 낭독 상태 화면은 여러 회일 때만 현재/전체 회차를 표시한다. 전체 대본
  하이라이트·자동 스크롤·한 어절 뒤로 UI는 Issue #30 범위로 남겼다.
- 시스템 설정 열기·자동 재시도 등 완성된 STT 실패·복구 UI는
  Issue #31 범위로 남겼다.

## 자동 검증

- `./scripts/test.sh`: 통과
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - 순수 Dart, Repository, 위젯을 포함한 Flutter 테스트 71개
- `flutter build apk --debug`: 통과
- `DEVELOPER_DIR=/Applications/Xcode-26.2.0.app/Contents/Developer flutter build ios --simulator --debug --no-codesign`: 통과
- `scripts/check_public_repo.sh`: 통과

Xcode 27.2의 Swift 6.4.2로 실행한 첫 iOS 빌드는 기존
`IosSpeechSession.swift`의 `AVAudioConverter` 호출에서 Swift 컴파일러 내부 오류가
발생했다. 저장소의 기존 STT 코드를 바꾸지 않고 설치된 Xcode 26.2로 다시 검증해
iOS Simulator Debug 빌드와 실행을 완료했다.

## 실제 실행과 화면 확인

- iOS 26.3 iPhone 17 Pro Simulator
  - [기본 글씨](images/issue-29/ios-default.png)
  - [Accessibility XL](images/issue-29/ios-accessibility-xl.png)
- Android API 36 Emulator
  - [기본 글씨](images/issue-29/android-default.png)
  - [Accessibility XL](images/issue-29/android-accessibility-xl.png)

양 플랫폼에서 직접 작성한 중립적 더미 대본을 목록에서 선택해 시작 설정 화면으로
이동했다. Android에서는 반복 피커를 실제로 스와이프하고 접근성 트리의 값이
`1회`에서 `2회`로 바뀌는 것도 확인했다. iOS Accessibility XL 첫 확인에서 고정
피커 행 높이로 글자가 겹치는 문제를 발견해 텍스트 배율에 따라 행 높이가 증가하도록
수정한 뒤 네 화면을 다시 확인했다.

## 자원 종료 근거

가짜 `SttService`와 제어 가능한 타이머를 사용한 Repository 테스트에서 다음 순서를
검증한다.

1. 최종 회차 완료 또는 나가기 즉시 상태를 완료/종료로 바꾸고 generation을 올린다.
2. 네이티브 `cancel`이 끝나기 전 도착한 이전 generation 이벤트를 무시한다.
3. 네이티브 인식 작업 취소 뒤 Dart STT 구독을 취소한다.
4. 완료·종료 뒤 타이머가 비활성이고 경과 시간이 더 바뀌지 않는다.
5. 중복 partial/final이 완료나 회차 감소를 반복하지 않는다.
