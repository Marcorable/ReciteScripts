---
name: start-task
description: 새 이슈·기능·조사 작업을 Orca의 독립 worktree와 새 Claude Code 또는 Codex 세션으로 시작한다. 작업을 격리하거나, 긴 대화를 새 세션으로 분리하거나, 기존 작업과 병렬로 진행해야 할 때 사용한다.
---

# 작업 시작

작업 하나에는 산출물 하나만 둔다. 구현·조사·리뷰처럼 목적이 달라지면 별도 작업으로 나눈다.

## 1. 범위 확인

- 작업명, 완료 기준, 대상 저장소와 베이스 브랜치를 확인한다.
- 저장소가 모든 작업에 이슈를 요구하면 먼저 이슈 번호를 확인한다. 그런 규칙이 없을 때만 이슈 없이 짧은 작업명을 쓸 수 있다.
- 이미 진행 중인 worktree를 재사용하지 않는다. 이전 작업을 이어야 하면 새 세션을 열되 worktree와 현재 상태를 명시한다.
- 실행 에이전트(Claude Code 또는 Codex)가 정해지지 않았으면 사용자에게 묻는다.

## 2. 새 worktree와 세션 생성

`orca` CLI로 새 worktree와 첫 에이전트 세션을 함께 만든다. 기존 세션은 재사용하지 않는다.

```bash
orca worktree create \
  --repo <확인한 저장소 selector> \
  --name <작업명> \
  --no-parent \
  --agent <claude|codex> \
  --prompt "<목표, 완료 기준, 검증 방법>" \
  --json
```

- 독립 작업은 확인한 저장소를 `--repo`로 지정하고 `--no-parent`를 사용한다. 필요하면 `--base-branch`도 명시한다.
- 현재 기능 브랜치에 쌓는 작업만 `--no-parent` 대신 확인한 `--parent-worktree <selector>`를 사용한다.
- `--agent`와 `--prompt`를 함께 사용해 첫 터미널이 새 세션이 되게 한다.
- 생성 결과의 worktree ID와 터미널 handle을 기록한다.

## 3. 첫 세션에 전달할 내용

프롬프트에는 아래만 포함한다.

- 목표와 완료 기준
- 이슈 링크/번호 또는 근거 자료
- 지켜야 할 팩·프로젝트 규칙
- 필수 검증 명령 또는 수동 확인 항목
- 범위를 벗어난 변경을 하지 말라는 경계

## 4. 상태 갱신

재현·구현·검증·대기처럼 의미 있는 전환마다 Orca worktree comment를 짧게 갱신한다.

```bash
orca worktree set --worktree <worktree-id> --comment "재현 완료; 구현 중" --json
```

새 세션이 필요해지면 이전 대화를 길게 이어가지 않는다. worktree comment와 PR·커밋·검증 결과를 읽을 수 있게 한 뒤 새 세션을 연다.
