#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Release hygiene verification must run on macOS." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MixPilot Autopilot"
APP_DIR="$ROOT/build/$APP_NAME.app"
DMG="$ROOT/build/MixPilot-Autopilot.dmg"
EXECUTABLE="$APP_DIR/Contents/MacOS/MixPilotAutopilot"

[[ -d "$APP_DIR" ]] || { echo "Missing app bundle: $APP_DIR" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "Missing release executable: $EXECUTABLE" >&2; exit 1; }
[[ -f "$DMG" ]] || { echo "Missing DMG: $DMG" >&2; exit 1; }

for pattern in '.DS_Store' '*.log' '*.jsonl' '*.sqlite' '*.sqlite3' '*.db-wal' '*.db-shm' '.env' '*.xcuserstate'; do
  if find "$APP_DIR" -name "$pattern" -print -quit | grep -q .; then
    echo "Forbidden generated or user file in app bundle: $pattern" >&2
    exit 1
  fi
done

if find "$APP_DIR" -path '*/xcuserdata/*' -print -quit | grep -q .; then
  echo "Xcode user data leaked into the application bundle." >&2
  exit 1
fi

if /usr/bin/xattr -lr "$APP_DIR" 2>/dev/null | grep -E 'com\.apple\.(quarantine|metadata)' >/dev/null; then
  echo "User-specific extended attributes remain in the app bundle." >&2
  exit 1
fi

TEXT_SCAN="$(mktemp "${TMPDIR:-/tmp}/mixpilot-release-text.XXXXXX")"
MOUNT_POINT="$(mktemp -d "${TMPDIR:-/tmp}/mixpilot-dmg-mount.XXXXXX")"
attached=0
cleanup() {
  if (( attached == 1 )); then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  rm -f "$TEXT_SCAN"
  rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

# Inspect text-like resources and property lists. The release executable is checked
# separately through Mach-O load commands after debug symbols have been stripped.
find "$APP_DIR" -type f \( \
  -name '*.plist' -o -name '*.json' -o -name '*.strings' -o -name '*.md' -o \
  -name '*.txt' -o -name '*.html' -o -name '*.css' -o -name '*.js' \
\) -print0 | while IFS= read -r -d '' file; do
  /usr/bin/strings -a "$file" || true
done > "$TEXT_SCAN"

if grep -E '/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/' "$TEXT_SCAN" >/dev/null; then
  echo "User-home path found in release resources." >&2
  grep -E '/Users/[A-Za-z0-9._-]+/|/home/[A-Za-z0-9._-]+/' "$TEXT_SCAN" | head -20 >&2
  exit 1
fi

if grep -E 'gh[pousr]_[A-Za-z0-9]{30,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "$TEXT_SCAN" >/dev/null; then
  echo "Credential-like material found in release resources." >&2
  exit 1
fi

if /usr/bin/otool -l "$EXECUTABLE" | grep -E '/Users/|/home/' >/dev/null; then
  echo "Mach-O load command contains a user-specific path." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_POINT" "$DMG" -quiet
attached=1
[[ -d "$MOUNT_POINT/$APP_NAME.app" ]] || { echo "DMG does not contain the app." >&2; exit 1; }
[[ -L "$MOUNT_POINT/Applications" ]] || { echo "DMG does not contain the Applications shortcut." >&2; exit 1; }

unexpected="$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 ! -name "$APP_NAME.app" ! -name Applications ! -name '.Trashes' ! -name '.fseventsd' -print)"
if [[ -n "$unexpected" ]]; then
  echo "Unexpected top-level DMG payload:" >&2
  echo "$unexpected" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/$APP_NAME.app"
echo "Release hygiene verified: no user data, home paths, credentials or runtime files."
