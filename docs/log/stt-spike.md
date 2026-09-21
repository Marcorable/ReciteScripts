# STT 스파이크 — 한국어 실시간 어절 추적 검증 (Issue #12)

> 2026-09-21. 스파이크 코드는 `spikes/stt/`에 있고 **버리는 코드**다.
> 이 문서가 산출물이다: 3종 테스트 결과, 지연 체감, 오인식 패턴, 하이라이트 단위 권고.

## 1. 환경

| 항목 | 값 |
|---|---|
| Xcode | 26.6 (17F113), iOS 26.5 SDK |
| 실기기 | iPhone 12 Pro — 테스트 전 iOS 18.7.8 → iOS 26 업데이트 필요 |
| 시뮬레이터 | iPhone 17 (iOS 26.5). `SpeechTranscriber.isAvailable == false` → 인식 검증 불가, UI 검증만 |
| API | `SpeechAnalyzer` + `SpeechTranscriber(locale: ko-KR)`, `reportingOptions: [.volatileResults]`, `attributeOptions: [.audioTimeRange]` |

## 2. 구현 요약

```
spikes/stt/
├── ScriptTracker/          순수 Swift 패키지 (매칭 로직, swift test 24개)
│   ├── TextNormalizer      공백·문장부호 제거 → 한글 자모 분해(NFD)
│   ├── ScriptTokenizer     공백 기준 어절 분리
│   ├── CursorMatcher       앵커 이후 어절과만 편집거리 DP 정렬, 커서 앞으로만
│   └── ReadingSession      volatile/final 처리, 수동 넘김 폴백
└── STTSpike/               SwiftUI 앱 (버리는 코드)
    ├── SpeechPipeline      마이크 → AVAudioConverter → SpeechAnalyzer
    ├── SpikeModel          이벤트 → 커서·지연 측정·로그
    └── ContentView         대본 하이라이트 + 자동 스크롤 + 진단 UI
```

### 매칭 방식

- **자모 스트림 정렬.** 한국어 STT의 띄어쓰기는 대본과 다르게 나온다("소리내어" vs "소리 내어"). 어절 단위 비교 대신, 앵커 이후 어절들을 이어 붙인 자모열과 발화 자모열을 편집거리로 정렬하고 어절 경계마다 정규화 거리를 구한다.
- **앵커/커서 분리.** 확정(final) 결과로만 앵커를 옮기고, 임시(volatile) 결과는 커서만 앞으로 당긴다. 커서는 절대 뒤로 가지 않는다.
- **탐색 범위 제한.** 발화 길이의 1.6배(최소 4어절)까지만 앞을 본다. 전체 대본 검색 없음 → 반복 낭독·반복 어절에서 안전.
- **임계값** 기본 0.45 (정규화 편집거리). 앱에서 슬라이더로 조정 가능.

### 확인한 함정

- `AVAudioEngine.inputNode.outputFormat` ≠ `SpeechAnalyzer.bestAvailableAudioFormat` → 에러 없이 전사 0건. `AVAudioConverter`로 변환한다. iOS 27에 추가된 `AnalyzerInputConverter`는 iOS 26 타깃에서 못 쓴다(SDK `.swiftinterface`에서 확인).
- `Mutex`는 `~Copyable`이라 오디오 탭 클로저에 직접 캡처할 수 없다 → `AudioClock` 클래스로 감쌌다.
- `AVAudioConverterInputBlock`은 `NS_SWIFT_SENDABLE`이라 `AVAudioPCMBuffer`를 `@unchecked Sendable` 박스로 넘겨야 한다.
- 시뮬레이터는 `SpeechTranscriber.isAvailable == false`. 인식은 실기기에서만.

## 3. 측정 방법

- **지연** = (지금까지 분석기에 넣은 오디오 초) − (결과의 `range.end` 초). 결과가 도착한 시점에 오디오가 얼마나 앞서 있는지. 임시 결과의 지연이 "자막처럼 느껴지는가"의 근사치.
- 앱 상단 "로그" 시트 → 공유 버튼으로 전체 로그를 텍스트로 뽑는다. 결과마다 `확정/임시`, 오디오 구간, 지연, 커서, 정규화 거리, 전사 텍스트가 찍힌다.

## 4. 테스트 결과 (실기기, Marco)

_실기기 테스트 후 채운다._

### ① 일상 문장

- 커서 추적:
- 지연(평균/최대):
- 오인식:

### ② 빠르고 작은 목소리

- 커서 추적:
- 지연(평균/최대):
- 오인식:

### ③ 음독·음차 (일상어가 아닌 텍스트)

- 커서 추적:
- 지연(평균/최대):
- 오인식:
- 대본 힌트(`AnalysisContext.contextualStrings`) 켰을 때 차이:

## 5. 결론

_실기기 테스트 후 채운다._

- 지연 체감:
- 오인식 패턴:
- **하이라이트 단위 권고 (어절 vs 문장):**
- MVP 구현에 넘길 것:
