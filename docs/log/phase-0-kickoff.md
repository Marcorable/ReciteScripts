# 0단계 킥오프 — 확정 사항과 실행 계획

> 2026-09-20 첫 세션에서 `~/Downloads/HANDOFF.md`를 검토하며 Marco와 확정한 내용.
> 새 세션은 **HANDOFF.md를 끝까지 읽은 뒤** 이 문서의 "실행 계획"부터 시작한다.
> HANDOFF.md 7번(미결정)과 8번(다음 할 일)은 아래 내용으로 갱신된 것으로 본다.

## 확정

| 항목 | 결정 |
|---|---|
| 레포 | `Marcorable/recite`, **Public** |
| 첫 커밋 | 기존 빈 커밋 `fc45a09`에 `.gitignore`를 넣어 **amend** (히스토리: ① .gitignore ② 규칙·역할 파일 …) |
| 4번 작업 원칙 | 1·2·3·4·5·7 확정. **6(프로젝트 구조: SPM vs Tuist vs XcodeGen)은 보류** → 3단계 Walking Skeleton 때 결정. AGENTS.md에 "미정"으로 표기 |
| 6번 GitHub 구조 | 확정 + **역할 축 추가** (아래) |
| 역할별 에이전트 | 5개 역할: Planner / Designer / Developer / QA / Marketer |
| 역할 파일 위치 | `docs/agents/<role>.md` = 모델 중립 **원본** (Claude/Codex/Slack 공용). `.claude/agents/<role>.md` = frontmatter(name/description/tools/model) + 원본 참조 |
| Project 필드 | `Status`(Backlog/Ready/In Progress/In Review/Done), `Phase`(0~6), `Model`(Claude/Codex/Marco), `Role`(Planner/Designer/Developer/QA/Marketer) |
| 라벨 | `agent-ready`, `needs-marco`, `phase:0`~`phase:6`, `role:planner` … `role:marketer` |
| Slack 연동 | 0단계 필수 아님. `needs-marco` Issue로 백로그에 둔다. 개발·QA 역할은 Xcode·시뮬레이터가 필요하므로 로컬(Orca)이 홈, Slack은 기획·마케팅 역할의 대화 창구 후보 |

## 보류 (Marco가 직접 결정)

- `docs/HANDOFF.md` 커밋 — 문서에 경력·구독 플랜·계정 고민 메모 등 개인 정보성 내용이 있어 Public 공개 전 Marco가 직접 검토. **에이전트는 커밋하지 않는다.**
- 프로젝트 구조(4번-6) — 3단계에서.
- HANDOFF.md 7번의 나머지 미결정 항목(앱 이름, 하이라이트 단위, 최소 iOS, 자녀 세팅 구조, 권리자 문의, 디자인 툴, 개발자 계정, Claude Code Action)은 그대로 미결정.

## 사전 작업 (Marco)

- [ ] `gh auth refresh -s project` — 현재 토큰 scope: `repo, read:org, gist, admin:public_key`. Project 생성(실행 계획 5번)에 필요.
- [ ] 레포 생성 후: Codex GitHub 연결 → Code review + Automatic reviews 켜기
- [ ] 레포 생성 후: CodeRabbit GitHub 앱 설치
- [ ] 레포 Settings → Secret scanning + Push protection 켜기

## 실행 계획 (에이전트)

1. `.gitignore` 작성(HANDOFF 4번 첨언 목록 + Xcode/SPM 기본) → 빈 커밋에 amend
2. `docs/agents/<role>.md` 5개 + `.claude/agents/<role>.md` 5개 + `AGENTS.md` 초안(`## Review guidelines` + 저작권 설계 제약 + 작업 원칙 1·2·3·4·5·7, 6은 미정 표기) + `CLAUDE.md`(`@AGENTS.md` 한 줄) + 이 문서 → 커밋. **커밋 전에 내용을 Marco에게 보여준다.**
3. **커밋 목록을 Marco에게 보여주고 확인받은 뒤** `gh repo create Marcorable/recite --public --source . --push`
4. Milestone 7개(`0. 기반 세팅` ~ `6. 출시 후`), 라벨 생성
5. Project 생성 + `Phase`, `Model`, `Role` 필드 추가 (project scope 필요)
6. Issue 목록 초안을 **표로 먼저 보여주고** 확인 후 생성 → milestone·label 지정 → Project 추가. STT 스파이크 Issue를 첫 번째 개발 Issue로. Slack 연동 Issue(`needs-marco`) 포함
7. HANDOFF 2번 앱 컨셉 기반으로 기획 디테일 질문 목록을 만들고 **하나씩** 묻는다
8. 생성된 Issue 목록을 표로 보고

## 대화 원칙 (HANDOFF 9번 재확인)

- 한 번에 하나의 주제. 여러 결정을 한꺼번에 묻지 않는다.
- 큰 그림 먼저, 그다음 디테일. 추상 설명보다 구체적 코드·명령어.
- 외부에 드러나는 작업(push, Issue 생성, 라벨 생성 등)은 실행 전에 목록을 보여주고 확인받는다.
- 제3자 텍스트(기도문·경전·가사·시)는 레포 어디에도 넣지 않는다.
