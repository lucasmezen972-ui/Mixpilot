#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "DMG packaging must run on macOS."
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MixPilot Autopilot"
APP_DIR="$ROOT/build/$APP_NAME.app"
STAGING="$ROOT/build/dmg-staging"
BUILD_DIR="$ROOT/build"
DMG_NAME="MixPilot-Autopilot.dmg"
DMG="$BUILD_DIR/$DMG_NAME"

[[ -d "$APP_DIR" ]] || "$ROOT/Scripts/build_release.sh"
rm -rf "$STAGING" "$DMG" "$DMG.sha256"
mkdir -p "$STAGING"
cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
(
  cd "$BUILD_DIR"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
  shasum -a 256 -c "$DMG_NAME.sha256"
)
echo "Packaged: $DMG"
