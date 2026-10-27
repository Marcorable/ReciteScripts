#!/bin/bash
# Flutter 포맷·정적 분석·테스트. AGENTS.md 8번 검증 루프 1·2단계.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

(cd "$FLUTTER_PROJECT" && dart format --output=none --set-exit-if-changed .)
run_flutter analyze
(cd "$FLUTTER_PROJECT" && dart test test/unit)
run_flutter test
