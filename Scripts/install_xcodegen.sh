#!/usr/bin/env bash
set -euo pipefail

readonly XCODEGEN_VERSION="2.45.4"
readonly XCODEGEN_COMMIT="24c60c314676f5fa176d7659c6679927db21f255"
readonly SOURCE_URL="https://github.com/yonaskolb/XcodeGen.git"
readonly WORK_DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mixpilot-xcodegen-${XCODEGEN_COMMIT}"
readonly INSTALL_DIR="${HOME}/.local/bin"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$INSTALL_DIR"

git -C "$WORK_DIR" init --quiet
git -C "$WORK_DIR" remote add origin "$SOURCE_URL"
git -C "$WORK_DIR" fetch --quiet --depth 1 origin "$XCODEGEN_COMMIT"
git -C "$WORK_DIR" checkout --quiet --detach FETCH_HEAD

test "$(git -C "$WORK_DIR" rev-parse HEAD)" = "$XCODEGEN_COMMIT"

swift build --package-path "$WORK_DIR" -c release --product xcodegen
cp "$WORK_DIR/.build/release/xcodegen" "$INSTALL_DIR/xcodegen"
chmod 0755 "$INSTALL_DIR/xcodegen"

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$INSTALL_DIR" >> "$GITHUB_PATH"
fi

actual_version="$($INSTALL_DIR/xcodegen --version)"
if [[ "$actual_version" != "Version: $XCODEGEN_VERSION" && "$actual_version" != "$XCODEGEN_VERSION" ]]; then
  echo "Unexpected XcodeGen version: $actual_version" >&2
  exit 1
fi

echo "Installed XcodeGen $XCODEGEN_VERSION from $XCODEGEN_COMMIT"
