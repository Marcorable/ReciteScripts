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
LOG="$DERIVED_DATA/logs/test.log"
grep -E "Test run with [0-9]+ test|Executed [0-9]+ test" "$LOG" | tail -5 || true

# xcodebuild test는 테스트를 하나도 못 찾아도 성공한다. 검증 루프가 거짓으로
# 통과하지 않도록, 실제로 1개 이상 실행됐는지 확인한다.
if ! grep -Eq "Test run with [1-9][0-9]* test|Executed [1-9][0-9]* test" "$LOG"; then
    echo "실행된 테스트가 0개다. 스킴의 테스트 타깃 설정을 확인한다. 전체 로그: $LOG" >&2
    exit 1
fi
