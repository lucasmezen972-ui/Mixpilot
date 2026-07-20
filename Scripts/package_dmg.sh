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
AUDIT_REPORT="$ROOT/ultimate-audit/ultimate-audit.json"
CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"

if [[ ! -f "$AUDIT_REPORT" ]]; then
  echo "No repository audit exists for this package. Rebuilding first." >&2
  "$ROOT/Scripts/build_release.sh"
fi

python3 - "$AUDIT_REPORT" "$CURRENT_HEAD" <<'PY'
import json
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
expected_head = sys.argv[2]
report = json.loads(report_path.read_text(encoding="utf-8"))
summary = report.get("summary", {})
if summary.get("errors") != 0:
    raise SystemExit("The repository audit contains blocking errors.")
if summary.get("git_head") != expected_head:
    raise SystemExit(
        "The repository changed after the last successful audit; rebuild before packaging."
    )
PY

[[ -d "$APP_DIR" ]] || "$ROOT/Scripts/build_release.sh"
rm -rf "$STAGING" "$DMG" "$DMG.sha256"
mkdir -p "$STAGING"
/usr/bin/ditto "$APP_DIR" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
(
  cd "$BUILD_DIR"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
  shasum -a 256 -c "$DMG_NAME.sha256"
)
echo "Packaged: $DMG"
