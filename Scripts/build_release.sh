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
PUBLISHER_PUBLIC_KEY="${MIXPILOT_PUBLISHER_PUBLIC_KEY_BASE64:-}"
REQUIRE_PUBLISHER_KEY="${MIXPILOT_REQUIRE_PUBLISHER_KEY:-0}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
ICONSET_DIR="$BUILD_DIR/MixPilot.iconset"
ICON_SOURCE="$BUILD_DIR/MixPilotAppIcon.jpg"

if [[ "$REQUIRE_PUBLISHER_KEY" == "1" && -z "$PUBLISHER_PUBLIC_KEY" ]]; then
  echo "A stable release requires MIXPILOT_PUBLISHER_PUBLIC_KEY_BASE64." >&2
  exit 1
fi

if [[ -n "$PUBLISHER_PUBLIC_KEY" ]]; then
  decoded_key_size="$(printf '%s' "$PUBLISHER_PUBLIC_KEY" | /usr/bin/base64 -D 2>/dev/null | wc -c | tr -d ' ')"
  if [[ "$decoded_key_size" != "32" ]]; then
    echo "MIXPILOT_PUBLISHER_PUBLIC_KEY_BASE64 must contain a 32-byte Ed25519 public key." >&2
    exit 1
  fi
fi

cd "$ROOT"
swift test
swift build -c release --product "$EXECUTABLE"

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$RESOURCES_DIR" "$ICONSET_DIR"
cp ".build/release/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"

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
  <key>MixPilotPublisherPublicKey</key><string>$PUBLISHER_PUBLIC_KEY</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.mixpilot.autopilot.auth</string>
      <key>CFBundleURLSchemes</key>
      <array><string>mixpilot-autopilot</string></array>
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

codesign --force --deep --sign "${CODE_SIGN_IDENTITY:--}" "$APP_DIR"
echo "Built: $APP_DIR"
