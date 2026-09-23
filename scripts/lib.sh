#!/bin/bash
# 빌드 스크립트 공통 설정. 각 스크립트가 source 한다.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 검증 대상. 환경 변수로 덮어쓸 수 있다.
#   PROJECT=spikes/stt/STTSpike.xcodeproj SCHEME=STTSpike ./scripts/build.sh
PROJECT="${PROJECT:-spikes/buildcheck/BuildCheck.xcodeproj}"
SCHEME="${SCHEME:-BuildCheck}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DERIVED_DATA="${DERIVED_DATA:-$REPO_ROOT/.build/DerivedData}"

PROJECT_PATH="$REPO_ROOT/$PROJECT"

# 이름으로 시뮬레이터 UDID를 찾는다. 없으면 사용 가능한 첫 iPhone으로 넘어간다.
simulator_udid() {
    local udid
    udid="$(xcrun simctl list devices available --json \
        | python3 -c "
import json,sys
name=sys.argv[1]
data=json.load(sys.stdin)['devices']
best=None
for runtime, devices in data.items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if d['name'] == name:
            print(d['udid']); sys.exit(0)
        if best is None and d['name'].startswith('iPhone'):
            best = d['udid']
if best:
    print(best)
" "$SIMULATOR_NAME")"
    if [ -z "$udid" ]; then
        echo "사용 가능한 iOS 시뮬레이터가 없다. Xcode에서 시뮬레이터 런타임을 설치한다." >&2
        return 1
    fi
    echo "$udid"
}

# xcodebuild 출력이 길어 실패 원인이 묻히므로, 요약만 남기고 전체 로그는 파일로 뺀다.
run_xcodebuild() {
    local log="$1"; shift
    mkdir -p "$(dirname "$log")"
    if xcodebuild "$@" > "$log" 2>&1; then
        grep -E "^\*\* .* \*\*$" "$log" || true
        return 0
    fi
    echo "실패. 전체 로그: $log" >&2
    grep -E "error:|Testing failed|The following build commands failed" "$log" | head -30 >&2
    return 1
}
