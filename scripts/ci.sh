#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ci-evidence
EVIDENCE="$PWD/build/ci-evidence"
DERIVED="$PWD/build/ci-derived"
SIMULATOR_RUNTIME="${SIMULATOR_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-2}"
SIMULATOR_ID=""
# Only remove the generated result bundle so local reruns are supported.
rm -rf "$EVIDENCE/build.xcresult"
cleanup() {
  if [ -n "$SIMULATOR_ID" ]; then
    xcrun simctl shutdown "$SIMULATOR_ID" >/dev/null 2>&1 || true
    xcrun simctl delete "$SIMULATOR_ID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
{
  xcodebuild -version
  swift --version
  xcodebuild -showsdks
  xcrun simctl list runtimes
} | tee "$EVIDENCE/environment.log"
if [ -n "${EXPECTED_XCODE_VERSION:-}" ]; then
  test "$(xcodebuild -version | head -n 1)" = "Xcode $EXPECTED_XCODE_VERSION"
fi
if [ -n "${EXPECTED_IOS_SDK:-}" ]; then
  test "$(xcrun --sdk iphonesimulator --show-sdk-version)" = "$EXPECTED_IOS_SDK"
fi
# Failures are propagated through tee, never retried or disabled to obtain green CI.
swift test --disable-sandbox 2>&1 | tee "$EVIDENCE/core-tests.log"
SIMULATOR_ID="$(xcrun simctl create 'PasseioCerto-CI' com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$SIMULATOR_RUNTIME")"
xcrun simctl boot "$SIMULATOR_ID"
xcrun simctl bootstatus "$SIMULATOR_ID" -b 2>&1 | tee "$EVIDENCE/simulator.log"
xcodebuild -project PasseioCerto.xcodeproj -scheme PasseioCerto \
  -sdk iphonesimulator -destination "id=$SIMULATOR_ID" \
  -derivedDataPath "$DERIVED" -resultBundlePath "$EVIDENCE/build.xcresult" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | tee "$EVIDENCE/ios-build.log"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/PasseioCerto.app"
test -f "$APP/Assets.car"
test -f "$APP/pt-BR.lproj/Localizable.strings"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$APP/Info.plist" | tee "$EVIDENCE/app-icon.log"
xcrun simctl install "$SIMULATOR_ID" "$APP"
xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" com.rebelato.PasseioCerto | tee "$EVIDENCE/launch.log"
sleep 3
xcrun simctl spawn "$SIMULATOR_ID" launchctl list > "$EVIDENCE/processes.log"
grep -F 'com.rebelato.PasseioCerto' "$EVIDENCE/processes.log"
xcrun simctl io "$SIMULATOR_ID" screenshot "$EVIDENCE/first-launch.png"
printf '%s\n' 'Core tests, full iOS build, assets, installation and launch passed.' | tee "$EVIDENCE/result.txt"
