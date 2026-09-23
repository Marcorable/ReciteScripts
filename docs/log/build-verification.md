# 빌드·테스트 검증 루프

> AGENTS.md 8번(검증 루프)을 실제로 돌리는 방법. Issue #8.

## 결론: MCP 없이 셸 스크립트로 간다

XcodeBuildMCP(서드파티 MCP 서버)는 도입하지 않았다. 이유는 셋이다.

- `xcodebuild` / `xcrun simctl`은 Xcode에 기본 포함되어 의존성이 0이다.
- 5단계 CI(GitHub Actions)에서는 MCP를 쓸 수 없어 어차피 셸 명령이 필요하다. 스크립트를 쓰면 로컬과 CI가 같은 경로를 탄다.
- Claude와 Codex가 같은 명령을 쓴다(원칙 5 교차 모델 리뷰). MCP는 모델별로 설정이 갈린다.

시뮬레이터 조작이 번거로워지면 그때 MCP를 **추가로** 붙인다.

## 명령

```bash
./scripts/build.sh                       # 빌드
./scripts/test.sh                        # 유닛 테스트
./scripts/screenshot.sh                  # 시뮬레이터 실행 + 스크린샷
./scripts/screenshot.sh accessibility-xl # 큰 글씨 스크린샷 (UI 변경 시)
```

대상 프로젝트는 환경 변수로 바꾼다. 기본값은 `spikes/buildcheck`다.

```bash
PROJECT=spikes/stt/STTSpike.xcodeproj SCHEME=STTSpike ./scripts/build.sh
SIMULATOR_NAME="iPhone 17 Pro" ./scripts/screenshot.sh
```

- 산출물·로그는 `.build/DerivedData/`에 모인다(`.gitignore` 처리됨).
- 빌드 로그 전문은 `.build/DerivedData/logs/*.log`. 스크립트는 성공 시 결과 줄만, 실패 시 `error:` 줄만 보여준다.
- 시뮬레이터는 이름으로 찾고, 없으면 사용 가능한 첫 iPhone으로 넘어간다.

## 검증 대상: `spikes/buildcheck`

검증 루프가 도는지 확인하기 위한 최소 앱이다. 실제 앱 골격은 3단계 Walking Skeleton(#24)에서 만들고, 프로젝트 구조(SPM / Tuist / XcodeGen)는 #23에서 정한다. **여기서 구조를 확정하지 않는다.**

- `BuildCheck` — SwiftUI 앱 타깃 하나, 화면 하나
- `BuildCheckTests` — Swift Testing 유닛 테스트 2개

`.xcodeproj`는 Xcode GUI 없이 손으로 작성했다(`objectVersion = 77`, 파일 시스템 동기화 그룹). 파일을 추가해도 `project.pbxproj`를 고칠 필요가 없다.

## 실행 결과 (2026-09-23, Xcode 26.6 / iOS 26.5 시뮬레이터)

| 단계 | 결과 |
|---|---|
| 빌드 | `** BUILD SUCCEEDED **` |
| 테스트 | `✔ Test run with 2 tests in 0 suites passed` |
| 시뮬레이터 + 스크린샷 | `docs/log/images/buildcheck-default.png` |
| 큰 글씨(Accessibility XL) | `docs/log/images/buildcheck-accessibility-xl.png` |

Marco 개입 없이 에이전트 세션에서 네 단계가 모두 돌았다.

## 막혔던 지점

- **`Scheme BuildCheck is not currently configured for the test action.`**
  공유 스킴(`xcshareddata/xcschemes/*.xcscheme`)에 빈 `<TestPlans></TestPlans>`가 있으면 `TestAction`이 무시된다. 요소를 지우니 통과했다. 스킴을 손으로 쓸 때는 빈 요소를 남기지 않는다.
- **`Executed 0 tests`가 찍히는데 실제로는 테스트가 돈다.**
  Swift Testing과 XCTest는 결과 줄 형식이 다르다. XCTest 집계(`Executed N tests`)는 Swift Testing 결과를 세지 않는다. `test.sh`는 두 형식을 모두 출력한다.
