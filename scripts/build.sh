#!/bin/bash
# Flutter Android·iOS 빌드. AGENTS.md 8번 검증 루프 3·4단계.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

echo "Android debug APK 빌드"
run_flutter build apk --debug

echo "iOS Simulator debug 빌드"
run_flutter build ios --simulator --debug
