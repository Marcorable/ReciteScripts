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

# 이름으로 시뮬레이터 UDID를 찾는다. 없으면 배포 타깃을 만족하는 런타임 중
# 가장 최신 iOS의 iPhone으로 넘어간다. iOS 18·26이 함께 깔린 머신에서
# 빌드가 안 되는 기기를 잡는 일을 막는다.
simulator_udid() {
    local min_os
    min_os="$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" \
        -showBuildSettings 2> /dev/null \
        | awk -F' = ' '/IPHONEOS_DEPLOYMENT_TARGET/ {print $2; exit}')"

    local udid
    udid="$(xcrun simctl list devices available --json \
        | python3 -c "
import json, re, sys

name = sys.argv[1]
min_os = sys.argv[2]


def version(text):
    nums = re.findall(r'[0-9]+', text)
    return tuple(int(n) for n in nums) if nums else ()


minimum = version(min_os)
best = None  # (런타임 버전, udid)

for runtime, devices in json.load(sys.stdin)['devices'].items():
    if 'iOS' not in runtime:
        continue
    runtime_version = version(runtime.rsplit('.', 1)[-1])
    if minimum and runtime_version < minimum:
        continue
    for device in devices:
        if device['name'] == name:
            print(device['udid'])
            sys.exit(0)
        if device['name'].startswith('iPhone'):
            if best is None or runtime_version > best[0]:
                best = (runtime_version, device['udid'])

if best:
    print(best[1])
" "$SIMULATOR_NAME" "$min_os")"

    if [ -z "$udid" ]; then
        echo "iOS ${min_os:-?} 이상을 지원하는 시뮬레이터가 없다. Xcode에서 런타임을 설치한다." >&2
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
