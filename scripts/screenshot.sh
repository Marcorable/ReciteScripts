#!/bin/bash
# 시뮬레이터 실행 + 스크린샷. AGENTS.md 8번 검증 루프 3·4단계.
#
#   ./scripts/screenshot.sh                      기본 글자 크기
#   ./scripts/screenshot.sh accessibility-xl     Accessibility XL (UI 변경 시 필수)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

VARIANT="${1:-default}"
OUT_DIR="${OUT_DIR:-$DERIVED_DATA/screenshots}"
UDID="$(simulator_udid)"

case "$VARIANT" in
    default)          CONTENT_SIZE="UICTContentSizeCategoryL" ;;
    accessibility-xl) CONTENT_SIZE="UICTContentSizeCategoryAccessibilityXL" ;;
    *) echo "variant는 default 또는 accessibility-xl" >&2; exit 1 ;;
esac

echo "시뮬레이터 부팅: $UDID"
xcrun simctl bootstatus "$UDID" -b > /dev/null

APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION-iphonesimulator/$SCHEME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "빌드 산출물이 없다. 먼저 ./scripts/build.sh 를 실행한다: $APP_PATH" >&2
    exit 1
fi

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist")"
echo "설치·실행: $BUNDLE_ID ($VARIANT)"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2> /dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" \
    -UIPreferredContentSizeCategoryName "$CONTENT_SIZE" > /dev/null

# 첫 프레임이 그려질 때까지 기다린다.
sleep 3

mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$SCHEME-$VARIANT.png"
xcrun simctl io "$UDID" screenshot --type=png "$OUT" > /dev/null 2>&1
echo "스크린샷: $OUT"
