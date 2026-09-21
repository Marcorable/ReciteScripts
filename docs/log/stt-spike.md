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
├── STTSpike/               SwiftUI 앱 (버리는 코드)
│   ├── SpeechPipeline      마이크 → AVAudioConverter → SpeechAnalyzer
│   ├── SpikeModel          이벤트 → 커서·지연 측정·로그
│   └── ContentView         대본 하이라이트 + 자동 스크롤 + 진단 UI
└── Harness/                macOS CLI. TTS 오디오를 실시간 속도로 넣어 파이프라인 재현 (README 참고)
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

## 4. Mac 사전 검증 (TTS 오디오, 2026-09-21)

실기기 전에 macOS 26.6.2(Apple Silicon)에서 `say -v Yuna`로 만든 오디오를 실시간 속도로 넣어 돌렸다.
TTS는 발음이 깨끗하고 잡음이 없으므로 **상한선**이다. 사람 목소리 결과는 5절에서 따로 본다.

### 4.1 ko-KR 지원·모델

- `SpeechTranscriber.supportedLocale(equivalentTo: ko-KR)` → `ko_KR` 반환. `AssetInventory.status` 처음엔 `.supported`, `downloadAndInstall()` 후 `.installed`. 이후 실행에서는 다운로드 없음.
- 파일 22050Hz → `bestAvailableAudioFormat` 16000Hz 1ch. `AVAudioConverter` 변환 경로로 정상 전사.

### 4.2 결정적 발견: `.fastResults` 없이는 실시간이 아니다

| 설정 | 임시 결과 도착 패턴 |
|---|---|
| `[.volatileResults]`만 | **~11.5초 단위로 묶여서** 도착 (11.6s에 80개, 23.1s에 55개, 30.8s에 51개). 인식은 증분으로 됐지만 전달이 묶임 |
| `[.volatileResults, .fastResults]` | **~0.93초 주기**로 꾸준히 도착. 주기는 투입 청크 크기(1024/4096/16384 프레임)와 무관 → 분석기 고유 주기 |
| `Options(priority: .userInteractive)` | 효과 없음. `fastResults`와 같이 주면 오히려 묶임 패턴으로 되돌아감 |

→ 낭독 추적에는 `.fastResults` 필수. 정확도 손실 여부는 실기기에서 확인(TTS에서는 확정 텍스트 동일).

### 4.3 결과 구조

- 임시 결과 = **미확정 구간 전체 텍스트(교체)**. 30초 낭독이 문장 경계에서도 확정되지 않고 임시 구간 하나로 자라다가 끝에 1번 확정됐다. → 매칭은 "자라는 텍스트"를 매번 앵커부터 다시 정렬해야 하고, 실제로 그렇게 동작한다.
- `audioTimeRange`: 임시 결과는 **run 1개(구간 전체)**. 어절별 시각은 확정 직전 마지막 패스에서만 나온다. → 실시간 하이라이트에 타이밍은 못 쓴다. 텍스트 정렬이 맞다.
- 첫 결과까지 걸린 시간: `fastResults` 켜면 ~1초.

### 4.4 3종 대본 결과 (`--fast`)

| 대본 | 커서 | 결과 수 | 오인식 |
|---|---|---|---|
| ① 일상 (60어절, 30.7s) | **60/60** | 200 | 빵집→방집, 갓→카스, 주전자에→주전자의, 읽다 만→입담한. 자모 정렬이 전부 흡수(거리 ≤ 0.05) |
| ② 빠르게 (52어절, 17.7s, TTS 속도 260) | **52/52** | 162 | 십 분→**10분**(숫자화), 괜히 든든하다→된 뒤 든하다. 흡수됨 |
| ③ 음독·음차 (28어절, 18.9s) | **17/28** | 67 | 사자성어풍(천지현명 …)은 8/8 추적. 만든 음절열은 일부 탈락(바니라 토로사 나비카 → 라 토로 나). **"일이삼사 오륙칠팔 구십백천"→"34678"**(숫자로 변환), "가나다라 마바사아…"는 전사 자체가 없음 |

- **대본 힌트(`AnalysisContext.contextualStrings`)는 효과 0.** `setContext`, 초기화 인자 두 경로 모두 결과가 바이트 단위로 동일. ko-KR 모델이 지원하지 않는 것으로 보인다(실기기 교차 확인).
- 숫자: 모델이 "십 분"→"10분", "일이삼사"→"34678"로 바꾼다. MVP 정규화에 **아라비아 숫자→한글 읽기 변환**을 넣어야 한다.

### 4.5 매칭 로직 관찰

- 임계값 0.45에서 오탐(엉뚱한 어절로 점프) 없음. 정상 매칭의 거리는 대부분 0.00~0.15.
- 어절이 절반만 발화된 상태("창ㅁ")에서는 이전 어절에 머문다(테스트 `partialLastWordDoesNotOvershoot`).
- 임시 텍스트가 무한히 자라므로 DP 비용이 O(발화 길이 × 탐색 범위)로 커진다. 30초/60어절에서는 문제 없었지만 MVP에서는 **안정된 접두어(마지막 N어절 앞)는 앵커를 당겨 잘라내는** 최적화가 필요하다.

## 5. 테스트 결과 (실기기, Marco)

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

## 6. 결론

_실기기 테스트 후 채운다._

- 지연 체감:
- 오인식 패턴:
- **하이라이트 단위 권고 (어절 vs 문장):**
- MVP 구현에 넘길 것:
