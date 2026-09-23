#!/bin/bash
# 유닛 테스트. AGENTS.md 8번 검증 루프 2단계.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

UDID="$(simulator_udid)"
echo "테스트: $SCHEME → 시뮬레이터 $UDID"

run_xcodebuild "$DERIVED_DATA/logs/test.log" \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    test

# Swift Testing과 XCTest는 결과 줄 형식이 다르므로 둘 다 본다.
grep -E "Test run with [0-9]+ test|Executed [0-9]+ test" "$DERIVED_DATA/logs/test.log" | tail -5 || true
