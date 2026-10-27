#!/bin/bash
# 빌드된 Flutter 앱을 실행하고 플랫폼별 스크린샷을 저장한다.
#
#   ./scripts/screenshot.sh android [default|large-text]
#   ./scripts/screenshot.sh ios [default|large-text]
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLATFORM="${1:-}"
VARIANT="${2:-default}"
mkdir -p "$OUTPUT_DIR/screenshots"

if [[ "$VARIANT" != "default" && "$VARIANT" != "large-text" ]]; then
    echo "variant는 default 또는 large-text여야 한다" >&2
    exit 1
fi

capture_android() {
    local adb="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
    local device="${ANDROID_DEVICE_ID:-}"
    local apk="$FLUTTER_PROJECT/build/app/outputs/flutter-apk/app-debug.apk"
    local app_id="${ANDROID_APP_ID:-com.marcorable.maltto}"

    if [ ! -x "$adb" ]; then
        echo "adb를 찾을 수 없다: $adb" >&2
        return 1
    fi
    "$adb" wait-for-device
    if [ -z "$device" ]; then
        device="$($adb devices | awk '$2 == "device" && $1 ~ /^emulator-/ {print $1; exit}')"
    fi
    if [ -z "$device" ]; then
        echo "실행 중인 Android Emulator가 없다" >&2
        return 1
    fi
    if [ ! -f "$apk" ]; then
        echo "Android 빌드 산출물이 없다. 먼저 ./scripts/build.sh를 실행한다" >&2
        return 1
    fi

    local attempt boot_completed boot_animation
    for attempt in {1..30}; do
        boot_completed="$($adb -s "$device" shell getprop sys.boot_completed | tr -d '\r')"
        boot_animation="$($adb -s "$device" shell getprop init.svc.bootanim | tr -d '\r')"
        if [ "$boot_completed" = "1" ] && [ "$boot_animation" = "stopped" ]; then
            break
        fi
        sleep 2
    done
    if [ "$boot_completed" != "1" ] || [ "$boot_animation" != "stopped" ]; then
        echo "Android Emulator 부팅이 완료되지 않았다" >&2
        return 1
    fi

    local original_scale
    original_scale="$($adb -s "$device" shell settings get system font_scale | tr -d '\r')"
    trap '$adb -s "$device" shell settings put system font_scale "$original_scale" >/dev/null' RETURN
    if [ "$VARIANT" = "large-text" ]; then
        $adb -s "$device" shell settings put system font_scale 1.3 >/dev/null
    else
        $adb -s "$device" shell settings put system font_scale 1.0 >/dev/null
    fi

    $adb -s "$device" install -r "$apk" >/dev/null
    $adb -s "$device" shell am force-stop "$app_id"
    $adb -s "$device" shell monkey -p "$app_id" 1 >/dev/null
    # 첫 설치에서는 Flutter 엔진 초기화가 길어질 수 있으므로 실제 첫 프레임을 기다린다.
    sleep 8
    $adb -s "$device" exec-out screencap -p > "$OUTPUT_DIR/screenshots/android-$VARIANT.png"
    echo "스크린샷: $OUTPUT_DIR/screenshots/android-$VARIANT.png"
}

capture_ios() {
    local udid="${IOS_SIMULATOR_UDID:-}"
    local app="$FLUTTER_PROJECT/build/ios/iphonesimulator/Runner.app"

    if [ -z "$udid" ]; then
        udid="$(xcrun simctl list devices booted --json | ruby -rjson -e 'puts JSON.parse(STDIN.read)["devices"].values.flatten.find { |d| d["name"].start_with?("iPhone") }&.fetch("udid", "")')"
    fi
    if [ -z "$udid" ]; then
        echo "부팅된 iOS Simulator가 없다" >&2
        return 1
    fi
    if [ ! -d "$app" ]; then
        echo "iOS 빌드 산출물이 없다. 먼저 ./scripts/build.sh를 실행한다" >&2
        return 1
    fi

    local bundle_id content_size
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")"
    if [ "$VARIANT" = "large-text" ]; then
        content_size="UICTContentSizeCategoryAccessibilityXL"
    else
        content_size="UICTContentSizeCategoryL"
    fi

    xcrun simctl install "$udid" "$app"
    xcrun simctl terminate "$udid" "$bundle_id" 2>/dev/null || true
    xcrun simctl launch "$udid" "$bundle_id" \
        -UIPreferredContentSizeCategoryName "$content_size" >/dev/null
    sleep 3
    xcrun simctl io "$udid" screenshot --type=png \
        "$OUTPUT_DIR/screenshots/ios-$VARIANT.png" >/dev/null
    echo "스크린샷: $OUTPUT_DIR/screenshots/ios-$VARIANT.png"
}

case "$PLATFORM" in
    android) capture_android ;;
    ios) capture_ios ;;
    *) echo "사용법: $0 <android|ios> [default|large-text]" >&2; exit 1 ;;
esac
