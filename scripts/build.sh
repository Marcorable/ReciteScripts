#!/bin/bash
# 시뮬레이터용 빌드. AGENTS.md 8번 검증 루프 1단계.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

UDID="$(simulator_udid)"
echo "빌드: $SCHEME ($CONFIGURATION) → 시뮬레이터 $UDID"

run_xcodebuild "$DERIVED_DATA/logs/build.log" \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "id=$UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build
