# 0단계 회고 — 기반 세팅과 Flutter 전환

기간: 2026-09-20 ~ 2026-10-23
관련 Issue: #1~#11, #46, #51

## 결론

0단계에서 Public 저장소의 보안·협업 규칙, Issue/PR 기반 작업 흐름, 교차 모델 리뷰, 재현 가능한 검증 진입점을 마련했다. 초기에는 Swift/SwiftUI 단일 iOS 앱으로 출발했으나, Marco와 MVP 방향을 다시 검토해 Flutter 단일 코드베이스로 iOS와 Android를 동시에 출시하기로 변경했다.

현재 개발 기준은 다음과 같다.

- Flutter 3.47.7 stable / Dart 3.13.5
- Android Studio를 주 IDE로 사용하고 Xcode를 iOS 빌드·시뮬레이터·서명·배포에 병행
- iOS 26+ / Android 13(API 33)+
- Flutter Cupertino 스타일 UI
- iOS `SpeechAnalyzer` + `SpeechTranscriber`, Android on-device `SpeechRecognizer`
- 서버 없이 로컬 저장만 사용하며 사용자 대본·음성을 기기 밖으로 보내거나 음성을 저장하지 않음

## 사용한 도구와 역할

| 영역 | 도구 | 사용 결과 |
|---|---|---|
| 저장소·작업 관리 | GitHub Issues, Milestones, Project, Actions | 모든 작업을 Issue로 추적하고 `user` 작업을 Marco에게 자동 할당 |
| 리뷰 | Codex GitHub Review, CodeRabbit | PR 생성 뒤 두 리뷰를 요청하고 P0/P1을 수정한 뒤 병합하는 흐름 검증 |
| 공통 에이전트 규칙 | `AGENTS.md`, 역할 문서, marcorable-kit | Claude와 Codex가 같은 규칙·commit·PR·review 스킬을 사용 |
| Flutter 개발 | Flutter/Dart CLI, Android Studio | stable SDK 고정, 분석·테스트·Android 빌드와 Emulator 실행 성공 |
| iOS 개발 | Xcode, iOS Simulator, `xcrun simctl` | Flutter iOS Simulator 빌드·실행·스크린샷 성공 |
| Android 개발 | Android SDK 36, API 36 Emulator, `adb` | minSdk 33 앱 빌드·설치·실행·스크린샷 성공 |
| 검증 자동화 | `scripts/test.sh`, `scripts/build.sh`, `scripts/screenshot.sh` | 포맷·분석·테스트와 양 플랫폼 빌드·화면 확인을 공통 명령으로 실행 |

## 된 것

- Secret scanning과 Push protection, PR 기반 보호 흐름을 활성화했다.
- Issue/PR 템플릿과 역할·단계별 라벨, Project 자동화, `user` 라벨 자동 할당을 마련했다.
- Codex와 CodeRabbit 리뷰가 실제 PR에서 동작하고, 리뷰 반영·resolve·재리뷰 루프까지 검증했다.
- Flutter 환경 검증 앱을 Android API 36 Emulator와 iOS 26.3 Simulator에서 실행했다.
- `dart format`, `flutter analyze`, `flutter test`, Android APK 빌드, iOS Simulator 빌드를 에이전트가 직접 실행했다.
- 기존 Swift 전용 검증 스크립트를 Flutter Android·iOS 공통 진입점으로 교체해 한 플랫폼만 확인하고 성공으로 보고하는 경로를 없앴다.
- Public 저장소에 제3자 텍스트, 사용자 대본·음성, 시크릿을 넣지 않는 P0 규칙을 확정했다.

## 계획과 달랐던 것

### Swift 단일 플랫폼에서 Flutter 양 플랫폼으로 전환

초기 계획은 Swift/SwiftUI, SwiftData, iOS 26 `SpeechAnalyzer` 중심이었다. MVP를 iOS와 Android에 동시에 출시한다는 목표가 확정되면서 UI와 공통 낭독 로직을 Flutter/Dart에 두고, 플랫폼 STT만 네이티브 어댑터로 분리하는 방향으로 변경했다.

이 전환으로 다음 항목을 폐기하거나 후속 설계로 넘겼다.

- SPM / Tuist / XcodeGen 선택은 Flutter 프로젝트 구조 결정으로 대체
- SwiftUI·SwiftData 전용 리뷰 규칙은 Flutter 상태·생명주기·브리지·로컬 저장 규칙으로 교체
- Swift 전용 `xcodebuild` 검증 진입점은 Flutter CLI와 양 플랫폼 도구 기반으로 교체
- 네이티브 브리지 방식(MethodChannel 또는 Pigeon)과 세부 디렉터리 구조는 Issue #23에서 결정

### 최소 OS 범위

MVP는 최신 온디바이스 STT API를 우선 검증하기 위해 iOS 26+와 Android API 33+로 시작한다. 출시 후 지원 범위를 낮추는 것은 가능하지만 단순 설정 변경이 아니다.

- iOS 18~25: `SFSpeechRecognizer` 기반 별도 어댑터 필요
- Android API 31~32: 온디바이스 지원·모델 상태를 확인하는 호환 어댑터 필요
- Flutter UI와 Dart 도메인·저장 모델은 하위 버전 어댑터 추가에 종속되지 않게 설계

## 실패·경고와 해결

| 상황 | 처리 |
|---|---|
| 초기 Swift 검증 스크립트가 Flutter·Android를 실행하지 않고도 성공할 수 있었음 | PR #53 리뷰에서 P1로 발견해 Flutter 양 플랫폼 진입점으로 교체 |
| Android 첫 실행 스크린샷이 Flutter 스플래시 화면에서 찍힘 | 첫 프레임 대기 시간을 늘리고 실제 화면을 다시 확인 |
| Flutter SDK와 Android 도구의 용량이 큼 | 중복 SDK를 제거하고 Homebrew Flutter 한 벌만 유지 |
| `flutter doctor`에 Android XR Preview·microXR 라이선스 경고가 남음 | 앱에 사용하지 않는 선택형 SDK이므로 경고 제거만을 위한 약관 동의는 하지 않음 |
| Gradle/JDK native access 향후 호환 경고 | 현재 빌드는 성공. 제품 프로젝트와 CI에서 공식 지원 조합을 다시 확인 |
| CodeRabbit docstring coverage 경고 | 생성된 최소 검증 코드에 대한 비차단 경고로 판단. P0/P1이 아니므로 불필요한 주석은 추가하지 않음 |

## Marco가 개입한 지점

- iOS·Android 동시 출시와 Flutter 단일 코드베이스 방향 확정
- Android Studio를 주 IDE로, Xcode를 iOS 전용 도구로 병행하는 방식 승인
- Cupertino 스타일 UI를 양 플랫폼에 적용하기로 확정
- MVP 최소 지원 범위를 iOS 26+ / Android API 33+로 시작하고 추후 어댑터로 낮추는 전략 승인
- PR 병합과 원격 작업 브랜치 삭제
- Apple·Google 개발자 계정 가입·결제·판매자 공개 정보는 계속 `user` 작업으로 보유

Marco가 앱 코드나 규칙 파일을 직접 수정한 사례는 없다.

## 아직 해결하지 않은 것

| 항목 | 상태·후속 Issue |
|---|---|
| Apple·Google 계정 형태와 출시 주체 | #9, `user`; 서명·배포 전에 완료 필요 |
| Android 온디바이스 한국어 STT 품질·오프라인 동작 | #12 스파이크에서 실측 |
| 상세 요구사항과 예외 상태 | #13에서 PRD 입력으로 정리 |
| Flutter PRD | #14 |
| 최소 화면·핵심 플로우 | #15 |
| 앱 이름 | #17, `user` |
| Flutter 구조·네이티브 STT 브리지 | #23 |
| Gradle/JDK 공식 지원 조합 | #24 Walking Skeleton과 CI에서 재검증 |

## 1단계 입력

다음 단계는 두 흐름으로 진행한다.

1. **기획 흐름:** #13 요구사항 정리 → #14 PRD → #15 화면·플로우
2. **기술 위험 흐름:** #12 Android 온디바이스 STT 스파이크

#12의 실기기 Pixel·Samsung 비교에는 기기가 필요하므로, 에뮬레이터에서 확인 가능한 범위와 실제 기기에서만 가능한 범위를 구분한다. #9와 #17은 Marco의 결정이 필요한 `user` 작업으로 개발·기획과 병렬 진행한다.

## marcorable-kit 승격 후보

아래 항목은 제품 프로젝트와 CI에서 한 번 더 검증한 뒤 Issue #32에서 `marcorable-flutter` 후보로 정리한다.

- production 앱은 Flutter stable의 정확한 버전을 문서와 CI에 함께 고정
- Android `minSdk`와 Flutter가 요구하는 `compileSdk`·`targetSdk`를 별도 결정으로 관리
- Flutter 프로젝트 생성 뒤 iOS 프로젝트에 로컬 Apple Team ID가 들어갔는지 검사하고 제거
- 선택형 SDK 라이선스를 단순히 `flutter doctor` 경고를 없애기 위해 승인하지 않음
- `dart format` → `flutter analyze` → `flutter test` → Android/iOS 빌드 → 양 플랫폼 스크린샷 순서의 검증 루프
- Flutter UI·Dart 도메인·플랫폼 STT 어댑터의 의존 방향 분리
