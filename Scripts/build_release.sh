#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This release build must run on macOS."
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MixPilot Autopilot"
EXECUTABLE="MixPilotAutopilot"
BUILD_DIR="$ROOT/build"
VERSION="${MIXPILOT_VERSION:-0.1.0}"
VERSION="${VERSION#v}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"

cd "$ROOT"
swift test
swift build -c release --product "$EXECUTABLE"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
  <key>CFBundleIdentifier</key><string>com.mixpilot.autopilot</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>${GITHUB_RUN_NUMBER:-1}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>MixPilot utilise l’audio uniquement pour surveiller le niveau et détecter les silences.</string>
  <key>NSScreenCaptureUsageDescription</key><string>MixPilot observe Serato afin de confirmer les titres chargés et les erreurs.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$APP_DIR"
echo "Built: $APP_DIR"
