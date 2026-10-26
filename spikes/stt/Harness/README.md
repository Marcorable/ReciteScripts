# Harness — Mac에서 SpeechAnalyzer 파이프라인 검증

실기기 없이 `SpeechAnalyzer` + `SpeechTranscriber(ko-KR)`와 `ScriptTracker` 매칭을 재현한다.
오디오 파일을 **실시간 속도로** 흘려 넣어 결과 도착 시각·커서 진행을 찍는다. macOS 26 필요.

`scripts/`의 대본은 앱의 `SampleScripts.swift`와 같은 직접 쓴 더미 문장이다 (제3자 텍스트 금지).

```sh
# 1. TTS로 오디오 생성 (한국어 음성 Yuna)
say -v Yuna -o /tmp/daily.aiff -f scripts/daily.txt
say -v Yuna -r 260 -o /tmp/fast.aiff -f scripts/fast.txt
say -v Yuna -r 150 -o /tmp/sino.aiff -f scripts/sino.txt

# 2. 실행
swift run Harness scripts/daily.txt /tmp/daily.aiff --fast
```

옵션: `--fast`(`.fastResults`), `--hints`/`--hints-init`(대본 어절을 `contextualStrings`로), `--threshold 0.45`,
`--chunk 4096`(투입 청크 프레임), `--no-pace`(실시간 대기 없이 투입), `--priority`, `--verbose`(청크 투입 시각·attributed run 출력).

출력 한 줄 = 결과 하나: `벽시계 확정/임시 [구간] 단어끝 지연 커서 거리 「텍스트」`.
- 지연 = 벽시계 − 마지막 run의 `audioTimeRange` 끝. 피딩이 실시간이므로 "그 오디오가 투입된 뒤 결과까지 걸린 시간".
