#!/bin/bash
# Flutter 검증 스크립트 공통 설정. 각 스크립트가 source 한다.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_PROJECT="${FLUTTER_PROJECT:-$REPO_ROOT/spikes/flutter_buildcheck}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/.build/flutter-verification}"

if [ ! -f "$FLUTTER_PROJECT/pubspec.yaml" ]; then
    echo "Flutter 프로젝트를 찾을 수 없다: $FLUTTER_PROJECT" >&2
    exit 1
fi

run_flutter() {
    (cd "$FLUTTER_PROJECT" && flutter "$@")
}
