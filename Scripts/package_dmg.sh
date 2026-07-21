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
FIRST_AUDIT_SCRIPT="$ROOT/Scripts/ultimate_repository_audit.py"
COUNTER_AUDIT_SCRIPT="$ROOT/Scripts/architecture_counter_audit.py"
AUDIT_REPORT="$ROOT/ultimate-audit/ultimate-audit.json"
COUNTER_AUDIT_REPORT="$ROOT/architecture-counter-audit/architecture-counter-audit.json"
CURRENT_HEAD="$(git -C "$ROOT" rev-parse HEAD)"

if [[ ! -f "$FIRST_AUDIT_SCRIPT" || ! -f "$COUNTER_AUDIT_SCRIPT" ]]; then
  echo "Both repository audit scripts are required before packaging." >&2
  exit 1
fi

if [[ ! -f "$AUDIT_REPORT" || ! -f "$COUNTER_AUDIT_REPORT" ]]; then
  echo "Both repository audits are required before packaging. Rebuilding first." >&2
  "$ROOT/Scripts/build_release.sh"
fi

python3 - "$AUDIT_REPORT" "$COUNTER_AUDIT_REPORT" "$CURRENT_HEAD" <<'PY'
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
    if summary.get("git_head") != expected_head:
        raise SystemExit(
            f"The repository changed after the last successful {report_name}; rebuild before packaging."
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
