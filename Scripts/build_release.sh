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
BRANDING_DIR="$ROOT/Branding"
VERSION="${MIXPILOT_VERSION:-0.1.0}"
VERSION="${VERSION#v}"
PUBLISHER="${MIXPILOT_PUBLISHER:-TRADIKOM BY LUCAS MEZEN}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICONSET_DIR="$BUILD_DIR/MixPilot.iconset"
ICON_SOURCE="$BUILD_DIR/MixPilotAppIcon.jpg"
AUDIT_DIR="$ROOT/ultimate-audit"

cd "$ROOT"

# A release candidate must be produced from the exact repository state that
# passed the repository-wide line-by-line audit. This gate is intentionally
# not bypassed by MIXPILOT_SKIP_TESTS.
rm -rf "$AUDIT_DIR"
python3 "$ROOT/Scripts/ultimate_repository_audit.py" --output-dir "$AUDIT_DIR"
python3 - "$AUDIT_DIR/ultimate-audit.json" <<'PY'
import json
import sys
from pathlib import Path

report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
summary = report.get("summary", {})
if summary.get("errors") != 0:
    raise SystemExit("Repository audit contains blocking errors.")
if not summary.get("git_head"):
    raise SystemExit("Repository audit did not record the audited Git commit.")
PY

if [[ "${MIXPILOT_SKIP_TESTS:-0}" == "1" ]]; then
  echo "Skipping Swift tests because MIXPILOT_SKIP_TESTS=1."
else
  swift test
fi
swift build -c release --product "$EXECUTABLE"

SWIFTPM_BIN_DIR="$(swift build -c release --show-bin-path | tail -n 1)"
if [[ ! -d "$SWIFTPM_BIN_DIR" ]]; then
  echo "SwiftPM release directory does not exist: $SWIFTPM_BIN_DIR" >&2
  exit 1
fi
if [[ ! -x "$SWIFTPM_BIN_DIR/$EXECUTABLE" ]]; then
  echo "Release executable is missing: $SWIFTPM_BIN_DIR/$EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$RESOURCES_DIR" "$ICONSET_DIR"
cp "$SWIFTPM_BIN_DIR/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"

shopt -s nullglob
resource_bundles=("$SWIFTPM_BIN_DIR"/*.bundle)
shopt -u nullglob

if (( ${#resource_bundles[@]} == 0 )); then
  echo "No SwiftPM resource bundles were produced in: $SWIFTPM_BIN_DIR" >&2
  exit 1
fi

for resource_bundle in "${resource_bundles[@]}"; do
  bundle_name="$(basename "$resource_bundle")"
  /usr/bin/ditto "$resource_bundle" "$RESOURCES_DIR/$bundle_name"
done

if [[ ! -d "$RESOURCES_DIR/MixPilot_MixPilotHelp.bundle" ]]; then
  echo "MixPilotHelp resources are missing from the packaged application." >&2
  exit 1
fi

if [[ ! -f "$BRANDING_DIR/MixPilotLogo.jpg.base64" || ! -f "$BRANDING_DIR/MixPilotAppIcon.jpg.base64" ]]; then
  echo "Branding assets are missing." >&2
  exit 1
fi

/usr/bin/base64 -D < "$BRANDING_DIR/MixPilotLogo.jpg.base64" > "$RESOURCES_DIR/MixPilotLogo.jpg"
/usr/bin/base64 -D < "$BRANDING_DIR/MixPilotAppIcon.jpg.base64" > "$ICON_SOURCE"

for size in 16 32 128 256 512; do
  /usr/bin/sips -s format png -z "$size" "$size" "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  /usr/bin/sips -s format png -z "$retina" "$retina" "$ICON_SOURCE" \
    --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/MixPilot.icns"
rm -rf "$ICONSET_DIR" "$ICON_SOURCE"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
  <key>CFBundleIdentifier</key><string>com.mixpilot.autopilot</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleGetInfoString</key><string>$APP_NAME $VERSION — $PUBLISHER</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>MixPilot</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>${GITHUB_RUN_NUMBER:-1}</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.mixpilot.autopilot.spotify</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>mixpilot-spotify</string>
      </array>
    </dict>
  </array>
  <key>NSHumanReadableCopyright</key><string>© 2026 $PUBLISHER. Tous droits réservés.</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>MixPilot utilise l’audio uniquement pour surveiller le niveau et détecter les silences.</string>
  <key>NSScreenCaptureUsageDescription</key><string>MixPilot peut observer l’interface visible du logiciel DJ sélectionné afin de confirmer les titres, les decks et les erreurs.</string>
  <key>NSLocalNetworkUsageDescription</key><string>MixPilot utilise le réseau local uniquement pour connecter l’application Remote sur ton iPhone au Mac.</string>
  <key>NSBonjourServices</key>
  <array>
    <string>_mixpilot._tcp</string>
  </array>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist"
registered_spotify_scheme="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$APP_DIR/Contents/Info.plist")"
if [[ "$registered_spotify_scheme" != "mixpilot-spotify" ]]; then
  echo "Spotify OAuth callback scheme is missing from the packaged application." >&2
  exit 1
fi

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  # Keep macOS Accessibility/Screen Recording grants stable across local builds.
  # An ad-hoc signature otherwise gets an implicit cdhash-only requirement that
  # changes every time the executable changes.
  codesign \
    --force \
    --deep \
    --sign - \
    --requirements='=designated => identifier "com.mixpilot.autopilot"' \
    "$APP_DIR"

  embedded_requirement="$(codesign --display --requirements - "$APP_DIR" 2>&1)"
  if [[ "$embedded_requirement" != *'designated => identifier "com.mixpilot.autopilot"'* ]]; then
    echo "The stable local designated requirement was not embedded." >&2
    exit 1
  fi
else
  codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
echo "Built: $APP_DIR"
