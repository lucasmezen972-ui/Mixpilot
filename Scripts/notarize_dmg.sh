#!/usr/bin/env bash
set -euo pipefail

required=(APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required notarization environment variable: $name" >&2
    exit 1
  fi
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMG_PATH="${1:-$ROOT/build/MixPilot-Autopilot.dmg}"
APP_PATH="$ROOT/build/MixPilot Autopilot.app"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

if [[ -d "$APP_PATH" ]]; then
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
fi

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "Notarized and verified: $DMG_PATH"
