# AGENTS.md

> 이 레포에서 일하는 모든 AI 에이전트(Claude Code, Codex, 그 외)의 **단일 규칙 원본**이다.
> `CLAUDE.md`는 이 파일을 import만 한다. 규칙을 바꿀 때는 이 파일만 고친다.
> 역할별 지침은 `docs/agents/<role>.md`에 있다.

## 1. 프로젝트

- 사용자가 직접 입력한 대본을 소리 내어 읽으면, 앱이 온디바이스 음성 인식으로 목소리를 따라가며 어절을 하이라이트하고, 끝까지 읽으면 남은 횟수를 줄여주는 iOS 앱.
- 이 프로젝트의 진짜 산출물은 앱이 아니라 **"AI로 앱을 출시하는 파이프라인"**이다. 기획 → 디자인 → 개발 → QA → 출시 → 운영 전 단계를 에이전트가 수행하고, Marco는 방향과 구조를 리뷰한다.
- 기술: Swift / SwiftUI, iOS 26+ `SpeechAnalyzer` + `SpeechTranscriber`(온디바이스), SwiftData 로컬 저장. **서버 없음.**
- 레포는 **Public**이다.

## 2. 작업 원칙

| # | 원칙 | 상태 |
|---|---|---|
| 1 | **규칙 단일 원본** — `AGENTS.md`가 원본. `CLAUDE.md`는 `@AGENTS.md` 한 줄만 둔다. | 확정 |
| 2 | **검증 루프** — 에이전트는 빌드 → 테스트 → 시뮬레이터 실행 → 스크린샷 확인까지 스스로 수행한다. "될 것 같다"가 아니라 실제 결과로 보고한다. | 확정 |
| 3 | **실패 시 규칙** — 에이전트가 문제를 못 풀어도 Marco는 코드를 고치지 않는다. 프롬프트·규칙·스펙을 고치고, 그 사례를 `docs/log/`에 기록한다. | 확정 |
| 4 | **리뷰 방식** — AI 1차 리뷰(Codex + CodeRabbit), Marco 2차 리뷰(구조·방향). Marco는 PR 코멘트만 남기고 수정은 에이전트가 한다. | 확정 |
| 5 | **교차 모델 리뷰** — 구현한 모델과 다른 모델이 리뷰한다 (Claude 구현 → Codex 리뷰, 또는 그 반대). | 확정 |
| 6 | **프로젝트 구조** — 앱 타깃은 껍데기, 로직은 로컬 SPM 패키지 / Tuist / XcodeGen 중 선택. | **미정** — 3단계 Walking Skeleton 때 결정 |
| 7 | **시크릿** — 서명 인증서, App Store Connect API 키는 레포 밖에 보관. 에이전트는 시크릿 파일을 읽거나 생성·커밋하지 않는다. 필요하면 `user` 라벨로 넘긴다. | 확정 |

### Marco가 코드를 직접 수정하지 않는다

이 프로젝트의 목표 중 하나는 **Marco가 직접 수정한 코드 0줄**이다. 에이전트는 Marco의 PR 코멘트를 받으면 코드를 고치고, 규칙이나 스펙이 잘못됐다면 그것을 고친다. Marco에게 "이 부분은 직접 고쳐주세요"라고 요청하지 않는다.

## 3. 설계 제약 — 저작권 (필수)

기도문·경전 등의 현행 한국어 번역문은 권리자가 전재·복제에 사전 승인을 요구한다. 따라서 이 앱과 레포는 다음을 지킨다.

1. **앱은 텍스트를 제공하지 않는다.** 모든 대본은 사용자가 자기 기기에 직접 입력한다.
2. **이 레포에 제3자 텍스트를 커밋하지 않는다.** 기도문·경전·가사·시 등을 테스트 픽스처, 샘플 데이터, SwiftUI Preview, 문서, 스크린샷 어디에도 넣지 않는다. **테스트와 프리뷰에는 직접 쓴 더미 문장만 쓴다.**
3. **서버 없음, 앱 내 공유 갤러리 없음.** 사용자 텍스트는 기기 밖으로 나가지 않는다. (나중에 공유를 넣더라도 파일을 주고받는 방식까지만.)
4. **특정 출처에서 텍스트를 긁어오는 기능을 만들지 않는다.** 붙여넣기는 사용자가 직접 한다.
5. OCR 등을 넣을 때는 범용 기능으로 표현한다 ("사진에서 텍스트 가져오기").
6. 스토어 문구는 용도 안내 수준으로 한다 ("기도문, 독경, 발표 대본을 입력해 사용할 수 있습니다").
7. 앱 이름·아이콘·UI 문구는 특정 종교·용도색 없이 **중립**으로 한다 ("기도" 대신 "낭독", "대본" 등).
8. 기본 탑재 텍스트가 필요해지면 권리자 서면 허락이 선행돼야 하며, 문의 여부는 Marco가 결정한다(`user`). 허락을 받을 경우를 대비해 "기본 묶음"을 넣을 수 있도록 데이터 구조는 열어둔다.

## 4. Public 레포 — 시크릿·개인정보

- 커밋 히스토리까지 전부 공개된다. 한 번 커밋된 시크릿은 삭제 커밋으로 되돌릴 수 없다(키 폐기·재발급 필요).
- 커밋 전에 항상 시크릿·개인정보(이메일 외 연락처, 계정 정보, 결제 정보 등)가 포함되지 않았는지 확인한다.
- `.gitignore`에 있는 패턴(`*.p8`, `*.p12`, `*.mobileprovision`, `.env*`, 시크릿 xcconfig 등)을 우회하지 않는다.
- CI에 필요한 값은 GitHub Actions Secrets로만 주입하고, 로그에 출력하지 않는다.

## 5. 범위

- MVP에 포함: 대본 CRUD(제목·본문·목표 횟수), 낭독 화면(어절 하이라이트 + 자동 스크롤 + 카운트다운), 수동 넘김/수동 카운트 폴백, 경과 시간, 글자 크기 설정, 온디바이스 한국어 STT, 로컬 저장.
- MVP 제외(v1.1 이후 후보): 숙지 모드, 묶음, 묶음 파일 내보내기/가져오기, OCR, 통계·연속 기록·알림, 대사 주고받기·가리기 게임류, 다국어.
- **제외 목록의 기능을 먼저 제안하거나 구현하지 않는다.** 범위를 넓히고 싶으면 Marco에게 묻는다.
- 상세 기획은 `docs/PRD.md`(1단계에서 작성)를 따른다.

## 6. GitHub 운용

- **Issue**가 모든 작업 단위다. 비개발 작업(기획·디자인·스토어 제출)도 Issue로 만든다.
- **Milestone**: `0. 기반 세팅` ~ `6. 출시 후`.
- **라벨**: `user`, `agent:planner` / `agent:designer` / `agent:developer` / `agent:qa` / `agent:marketer`.
- **자동 할당**: `user` 라벨이 붙은 Issue는 Marco(`Marcorable`)에게 자동 할당한다.
- **Project 필드**: `Status`(Backlog / Ready / In Progress / In Review / Done), `Phase`(0~6), `Model`(Claude / Codex / Marco), `Role`(Planner / Designer / Developer / QA / Marketer).
- **브랜치**: Issue 번호 기반 `feature/#N`. worktree로 병렬 작업.
- **PR**: 제목은 `[Category] Summary` 형식으로 쓴다. Category는 `Feature` / `Fix` / `Documentation` / `Chore` / `Refactoring` / `Test` / `Style` 중에서 고른다. 본문에 `Closes #N`. 한 PR은 한 Issue. PR을 한꺼번에 여러 개 열지 않는다(CodeRabbit OSS rate limit).
- **커밋 메시지**: [Udacity Git Commit Message Style](https://udacity.github.io/git-styleguide/)을 따른다.
  - 제목: `type: Subject` — 타입은 `feat` / `fix` / `docs` / `style` / `refactor` / `test` / `chore`, 영어 명령형, 첫 글자 대문자, 마침표 없음, 50자 이내.
  - 본문(선택): 제목과 빈 줄로 구분, 한 줄 72자 이내, "무엇을·왜"를 적는다. 한국어 가능.
  - 푸터(선택): `Closes #N` 등 Issue 참조.

### 리뷰 흐름

```
PR 오픈 → Codex 자동 리뷰 (1차, P0/P1만)
       + 에이전트가 PR 생성 직후 `@coderabbitai review` 코멘트 (1차 보조)
       → 에이전트가 피드백 반영 → CI 통과
       → Marco 리뷰 (2차, 구조·방향) → 머지
```

- 구현한 모델과 다른 모델이 리뷰한다(원칙 5).
- Codex 피드백 반영은 `@codex address that feedback` 코멘트 또는 구현 에이전트가 처리한다.

## 7. Review guidelines

리뷰어(Codex, CodeRabbit, Claude, Marco)는 아래 기준으로 본다. P0/P1은 머지 차단.

### P0 — 반드시 막는다
- 제3자 텍스트(기도문·경전·가사·시)가 코드·테스트·프리뷰·문서·스크린샷에 포함됨 (3번 제약)
- 시크릿·개인정보 커밋 (4번)
- 사용자 텍스트나 음성이 기기 밖으로 나가는 코드 (네트워크 호출, 서버 전송, 애널리틱스에 본문 포함)
- 음성 녹음을 저장하는 코드
- MVP 제외 기능을 몰래 구현

### P1 — 수정 후 머지
- **동시성**: `@MainActor` 누락으로 UI 상태를 백그라운드에서 변경, Swift 6 strict concurrency 경고, `Task` 취소 처리 누락, actor 격리 위반
- **STT 파이프라인**: `AVAudioEngine` 입력 포맷과 `SpeechAnalyzer.bestAvailableAudioFormat` 불일치(전사 0건 함정), 권한·로케일·모델 설치 상태 미확인, 인식 실패 시 수동 폴백 없음
- **매칭 로직**: 커서가 뒤로 가는 코드, 전체 전사문에서 위치를 검색하는 코드(반복 낭독에서 깨짐), 임계값 하드코딩이 UI에 섞임
- **아키텍처**: 매칭 로직이 UI·STT와 분리되지 않음, 순수 로직에 유닛 테스트 없음, SwiftData 모델 변경에 마이그레이션 고려 없음
- **접근성**: Dynamic Type 미지원, 큰 글씨에서 레이아웃 깨짐, 터치 타깃 44pt 미만, VoiceOver 라벨 없음 (어르신 사용자 전제)
- **테스트**: 기존 테스트 삭제·비활성화, 테스트 없이 로직 변경

### P2 — 권장
- SwiftUI 뷰가 200줄 넘음 → 분리
- `ObservableObject` 대신 `@Observable` 사용
- 강제 언래핑(`!`), `try!`, `as!`
- 매직 넘버 → 이름 있는 상수
- 불필요한 `AnyView`, 과도한 `GeometryReader`
- 한국어 UI 문구가 코드에 하드코딩 (Localizable 사용)

### 리뷰어가 하지 않는 것
- 스타일 취향(들여쓰기, 줄바꿈)은 SwiftFormat/SwiftLint에 맡긴다.
- P2를 이유로 머지를 막지 않는다.

## 8. 검증 루프 (원칙 2 상세)

에이전트는 코드를 바꾸면 다음을 스스로 실행하고 결과를 PR에 적는다.

1. 빌드 (`xcodebuild` 또는 XcodeBuildMCP)
2. 유닛 테스트
3. 시뮬레이터 실행 + 해당 화면 스크린샷
4. (UI 변경 시) 큰 글씨(Accessibility XL) 스크린샷 1장

빌드·테스트 실패를 "환경 문제"로 넘기지 않는다. 못 풀면 Issue에 상황을 적고 `user`를 붙인다.

## 9. 문서와 로그

```
docs/
├── PRD.md              ← 1단계에서 작성
├── agents/<role>.md    ← 역할별 지침 원본 (모델 중립)
├── design/tokens.md    ← 2단계
└── log/                ← phase-N.md, stt-spike.md, 리뷰 품질 비교 등
```

- 단계가 끝날 때마다 `docs/log/phase-N.md`에 "어떤 도구로 / 된 것 / 안 된 것 / Marco가 개입한 지점"을 기록한다.
- 에이전트가 못 푼 문제와 그때 고친 규칙·프롬프트도 같은 로그에 남긴다(원칙 3).

## 10. Marco와 대화하는 방식

- **한 번에 하나의 주제.** 여러 결정을 한꺼번에 묻지 않는다.
- 큰 그림을 먼저 보여주고 디테일로 들어간다.
- 추상적 설명보다 구체적인 코드·명령어 예제로 답한다.
- **외부에 드러나는 작업**(push, Issue·라벨·Milestone 생성, PR 오픈, 코멘트)은 실행 전에 목록을 보여주고 확인받는다.
- "확정" 표시가 없는 항목은 제안 상태다. 확정된 것처럼 밀어붙이지 않는다.
- 한국어로 소통한다.

## 11. 역할

| 역할 | 파일 | 홈 |
|---|---|---|
| Planner | `docs/agents/planner.md` | Orca / Slack 후보 |
| Designer | `docs/agents/designer.md` | Orca |
| Developer | `docs/agents/developer.md` | Orca (Xcode·시뮬레이터 필요) |
| QA | `docs/agents/qa.md` | Orca (Xcode·시뮬레이터 필요) |
| Marketer | `docs/agents/marketer.md` | Orca / Slack 후보 |

Claude Code용 서브에이전트 정의는 `.claude/agents/<role>.md`에 있으며, 본문은 위 원본을 참조한다.
