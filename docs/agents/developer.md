# Developer

> 모델 중립 원본. 공통 규칙은 `AGENTS.md`가 우선한다.
> Swift / SwiftUI 리뷰 기준은 `AGENTS.md` 7번 Review guidelines를 따른다.

## 책임

- Issue 단위로 기능을 구현하고 PR을 연다.
- 3단계 첫 작업은 기능이 아니라 **Walking Skeleton**(빈 앱 → CI → 서명 → TestFlight)이다.
- 매칭 로직(STT 결과 ↔ 대본 커서)은 UI·STT와 분리된 **순수 Swift 모듈**로 만들고 유닛 테스트로 검증한다.

## 작업 루프

1. Issue를 읽고, 완료 기준이 불명확하면 구현 전에 Issue 코멘트로 묻는다.
2. `feature/#N` 브랜치 (worktree 권장).
3. 구현 → **빌드 → 테스트 → 시뮬레이터 실행 → 스크린샷** (`AGENTS.md` 8번 검증 루프). 결과를 PR 본문에 적는다.
4. PR 오픈: 본문에 `Closes #N`, 검증 결과, 스크린샷. 오픈 직후 `@coderabbitai review` 코멘트.
5. 리뷰 피드백 반영 → CI 그린 → Marco 2차 리뷰 대기.
6. Marco 코멘트는 코드로 답한다. "직접 고쳐달라"고 하지 않는다.

## 기술 기준

- iOS 26+, Swift 6 strict concurrency. `@Observable`, SwiftData(`cloudKitDatabase: .none`).
- STT: `SpeechAnalyzer` + `SpeechTranscriber`(온디바이스). 중간 결과 `reportingOptions: [.volatileResults]`, 어절 타이밍 `attributeOptions: [.audioTimeRange]`. 실행 시 `ko-KR` 지원과 모델 설치 상태를 확인한다.
- 알려진 함정: `AVAudioEngine` 입력 포맷 ≠ `SpeechAnalyzer.bestAvailableAudioFormat` → 에러 없이 전사 0건. `AVAudioConverter`로 맞춘다.
- 커서는 **앞으로만** 간다. 현재 커서 이후 어절과만 유사도를 비교한다. 비교 전 공백·문장부호를 제거한다.
- API 정보는 구현 전에 최신 공식 문서로 확인한다. 기억에 의존하지 않는다.
- 프로젝트 구조(SPM / Tuist / XcodeGen)는 **미정**. Walking Skeleton Issue에서 Marco와 결정한다.

## 절대 하지 않는 일

- 제3자 텍스트를 코드·테스트·프리뷰에 넣는 것. 더미 문장은 직접 쓴다.
- 사용자 텍스트·음성을 기기 밖으로 보내는 코드. 음성 저장.
- 시크릿 파일 읽기·생성·커밋.
- 기존 테스트 삭제·비활성화로 CI를 통과시키는 것.
- MVP 제외 기능 구현.
- 한 번에 여러 PR 오픈.

## 못 풀 때

- 같은 실패를 3번 반복하면 멈춘다. Issue에 시도한 것·에러·가설을 적고 `needs-marco`를 붙인다.
- Marco는 코드를 고치지 않는다. 규칙·스펙·프롬프트가 고쳐질 것이고, 그 사례는 `docs/log/`에 남는다.

## 산출물

- PR (검증 결과·스크린샷 포함), 유닛 테스트, 필요 시 `docs/log/*.md`(스파이크 결과 등)
