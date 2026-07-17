#!/usr/bin/env bash
set -euo pipefail

fail_if_found() {
  local pattern="$1"
  shift
  local message="$1"
  shift

  if grep -RInE --exclude-dir=.build --exclude-dir=.git "$pattern" "$@"; then
    echo "Architecture check failed: $message" >&2
    exit 1
  fi
}

# Historical aliases may remain in compatibility files, but never in active
# product layers.
fail_if_found \
  'SeratoPlaylistImporter\(' \
  'the active application must use VisiblePlaylistImporter' \
  Sources/MixPilotApp Sources/MixPilotRuntime Sources/MixPilotRemoteBridge

if grep -RInE \
  --exclude='SeratoAccessibilityBridge.swift' \
  --exclude-dir=.build \
  --exclude-dir=.git \
  'SeratoAccessibilityBridge\(' Sources; then
  echo 'Architecture check failed: active source must use DJAccessibilityBridge' >&2
  exit 1
fi

fail_if_found \
  'MappedSeratoController' \
  'the active runtime must depend on DJBackend, not MappedSeratoController' \
  Sources/MixPilotApp Sources/MixPilotRuntime Sources/MixPilotRemoteBridge

fail_if_found \
  'StandardDJBackendAdapter' \
  'backend-specific capability rules must not be hidden behind the former shared adapter' \
  Sources/MixPilotSystem

for policy in SeratoBackendPolicy RekordboxBackendPolicy DjayBackendPolicy; do
  grep -q "struct ${policy}" Sources/MixPilotSystem/DJBackendAdapters.swift || {
    echo "Architecture check failed: missing backend-specific policy: ${policy}" >&2
    exit 1
  }
done

fail_if_found \
  'DJSoftwareSelectionStore\.current' \
  'no code may recreate a default DJ software selection' \
  Sources

if grep -RInE \
  --exclude='DJSoftware.swift' \
  --exclude='SeratoAccessibilityBridge.swift' \
  --exclude-dir=.build \
  --exclude-dir=.git \
  'DJSoftwareSelectionStore\.selected' Sources; then
  echo 'Architecture check failed: active source must use DJBackendSelectionStoring' >&2
  exit 1
fi

# The old property remains source-compatible in DJBackend.swift for the moment,
# but active source code must use the strict isConfirmedForLive contract.
if grep -RIn --exclude='DJBackend.swift' --exclude-dir=.build --exclude-dir=.git \
  'isVerifiedForLive' Sources; then
  echo 'Architecture check failed: use isConfirmedForLive instead of isVerifiedForLive' >&2
  exit 1
fi

fail_if_found \
  'djBackend:[[:space:]]*"rekordbox"' \
  'online services must not hardcode rekordbox as the selected backend' \
  Sources

fail_if_found \
  'dj_backend"?[[:space:]]*:[[:space:]]*"rekordbox"' \
  'serialized cloud payloads must use the selected backend dynamically' \
  Sources

for deleted in \
  Sources/MixPilotApp/ContentView.swift \
  Sources/MixPilotApp/BrandedRootView.swift \
  Sources/MixPilotApp/AdvancedContentView.swift; do
  if [[ -e "$deleted" ]]; then
    echo "Architecture check failed: obsolete parallel UI still exists: $deleted" >&2
    exit 1
  fi
done

echo 'Source architecture consistency: OK'
