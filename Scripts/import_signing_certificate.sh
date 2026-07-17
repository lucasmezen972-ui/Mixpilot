#!/usr/bin/env bash
set -euo pipefail

required=(APPLE_CERTIFICATE_P12_BASE64 APPLE_CERTIFICATE_PASSWORD APPLE_SIGNING_IDENTITY)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required signing environment variable: $name" >&2
    exit 1
  fi
done

KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/mixpilot-signing.keychain-db"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(uuidgen)}"
CERTIFICATE_PATH="${RUNNER_TEMP:-/tmp}/mixpilot-developer-id.p12"

printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode > "$CERTIFICATE_PATH"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" \
  -P "$APPLE_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"
security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db
security find-identity -v -p codesigning "$KEYCHAIN_PATH"

echo "CODE_SIGN_IDENTITY=$APPLE_SIGNING_IDENTITY" >> "${GITHUB_ENV:-/dev/null}"
echo "MIXPILOT_SIGNING_KEYCHAIN=$KEYCHAIN_PATH" >> "${GITHUB_ENV:-/dev/null}"
rm -f "$CERTIFICATE_PATH"
