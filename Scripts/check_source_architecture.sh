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

# Historical aliases may remain in compatibility files, but never in the active
# application, runtime or Remote bridge.
fail_if_found \
  'SeratoPlaylistImporter\(' \
  'the active application must use VisiblePlaylistImporter' \
  Sources/MixPilotApp Sources/MixPilotRuntime Sources/MixPilotRemoteBridge

fail_if_found \
  'SeratoAccessibilityBridge\(' \
  'the active product layers must use DJAccessibilityBridge' \
  Sources/MixPilotApp Sources/MixPilotRuntime Sources/MixPilotRemoteBridge

fail_if_found \
  'MappedSeratoController' \
  'the active runtime must depend on DJBackend, not MappedSeratoController' \
  Sources/MixPilotApp Sources/MixPilotRuntime Sources/MixPilotRemoteBridge

fail_if_found \
  'DJSoftwareSelectionStore\.current' \
  'no code may recreate a default DJ software selection' \
  Sources

# The old property remains source-compatible in DJBackend.swift for the moment,
# but new code must use the strict isConfirmedForLive contract.
if grep -RIn --exclude='DJBackend.swift' --exclude-dir=.build --exclude-dir=.git \
  'isVerifiedForLive' Sources Tests; then
  echo 'Architecture check failed: use isConfirmedForLive instead of isVerifiedForLive' >&2
  exit 1
fi

fail_if_found \
  'djBackend:[[:space:]]*"rekordbox"|dj_backend["'"']?[[:space:]]*:[[:space:]]*"rekordbox"' \
  'online services must serialize the selected backend dynamically' \
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
