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
COUNTER_AUDIT_DIR="$ROOT/architecture-counter-audit"
CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
AUDIT_WORKTREE=""

cleanup_audit_worktree() {
  if [[ -n "$AUDIT_WORKTREE" ]]; then
    git -C "$ROOT" worktree remove --force "$AUDIT_WORKTREE" >/dev/null 2>&1 || true
  fi
}
trap cleanup_audit_worktree EXIT

cd "$ROOT"

# Audit the exact Git commit from a clean detached worktree. Generated Xcode
# projects, simulator logs and untracked CI outputs cannot alter the verdict.
rm -rf "$AUDIT_DIR" "$COUNTER_AUDIT_DIR"
AUDIT_WORKTREE="$(mktemp -d "${TMPDIR:-/tmp}/mixpilot-release-audit.XXXXXX")"
rmdir "$AUDIT_WORKTREE"
git -C "$ROOT" worktree add --detach "$AUDIT_WORKTREE" "$CURRENT_HEAD" >/dev/null
python3 "$AUDIT_WORKTREE/Scripts/ultimate_repository_audit.py" \
  --output-dir "$AUDIT_WORKTREE/ultimate-audit"
python3 "$AUDIT_WORKTREE/Scripts/architecture_counter_audit.py" \
  --output-dir "$AUDIT_WORKTREE/architecture-counter-audit"
cp -R "$AUDIT_WORKTREE/ultimate-audit" "$AUDIT_DIR"
cp -R "$AUDIT_WORKTREE/architecture-counter-audit" "$COUNTER_AUDIT_DIR"
git -C "$ROOT" worktree remove --force "$AUDIT_WORKTREE" >/dev/null
AUDIT_WORKTREE=""

python3 - \
  "$AUDIT_DIR/ultimate-audit.json" \
  "$COUNTER_AUDIT_DIR/architecture-counter-audit.json" \
  "$CURRENT_HEAD" <<'PY'
import json
import sys
from pathlib import Path

expected_head = sys.argv[3]
for report_name, report_path in (
    ("line-by-line audit", Path(sys.argv[1])),
    ("architecture counter-audit", Path(sys.argv[2])),
):
    report = json.loads(report_path.read_text(encoding="utf-8"))
    summary = report.get("summary", {})
    if summary.get("errors") != 0:
        raise SystemExit(f"The {report_name} contains blocking errors.")
    if report_name == "architecture counter-audit":
        checks = summary.get("checks")
        if not isinstance(checks, int) or checks < 50:
            raise SystemExit(
                f"The {report_name} executed insufficient checks: {checks!r}."
            )
    if summary.get("git_head") != expected_head:
        raise SystemExit(
            f"The {report_name} does not match the current Git commit."
        )
PY

tests_already_validated=0
if [[ "${GITHUB_ACTIONS:-}" == "true" && -s "$ROOT/swift-test.log" ]]; then
  if grep -Eq \
    'Test run with [0-9]+ tests passed|Executed [0-9]+ tests, with 0 failures' \
    "$ROOT/swift-test.log"; then
    tests_already_validated=1
  fi
fi

if [[ "${MIXPILOT_SKIP_TESTS:-0}" == "1" ]]; then
  echo "Skipping Swift tests because MIXPILOT_SKIP_TESTS=1."
elif (( tests_already_validated == 1 )); then
  echo "Reusing the successful Swift test gate from this GitHub Actions job."
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
/usr/bin/strip -S "$APP_DIR/Contents/MacOS/$EXECUTABLE"

shopt -s nullglob
resource_bundles=("$SWIFTPM_BIN_DIR"/*.bundle)
shopt -u nullglob

if (( ${#resource_bundles[@]} == 0 )); then
  echo "No SwiftPM resource bundles were produced in: $SWIFTPM_BIN_DIR" >&2
  exit 1
fi

for resource_bundle in "${resource_bundles[@]}"; do
  bundle_name="$(basename "$resource_bundle")"
  COPYFILE_DISABLE=1 /usr/bin/ditto --norsrc "$resource_bundle" "$RESOURCES_DIR/$bundle_name"
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
      <array><string>mixpilot-spotify</string></array>
    </dict>
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
  <array><string>_mixpilot._tcp</string></array>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist"
registered_spotify_scheme="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$APP_DIR/Contents/Info.plist")"
if [[ "$registered_spotify_scheme" != "mixpilot-spotify" ]]; then
  echo "Spotify OAuth callback scheme is missing from the packaged application." >&2
  exit 1
fi
registered_account_scheme="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:1:CFBundleURLSchemes:0' "$APP_DIR/Contents/Info.plist")"
if [[ "$registered_account_scheme" != "mixpilot-autopilot" ]]; then
  echo "MixPilot account callback scheme is missing from the packaged application." >&2
  exit 1
fi

find "$APP_DIR" -name '.DS_Store' -delete
/usr/bin/xattr -cr "$APP_DIR"

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
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
