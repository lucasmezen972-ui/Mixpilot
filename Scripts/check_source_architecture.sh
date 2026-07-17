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

fail_if_found \
  'message\.version[[:space:]]*==[[:space:]]*1' \
  'Remote peers must negotiate the documented protocol range instead of hardcoding v1' \
  Sources/MixPilotRemoteBridge Mobile/MixPilotRemote/Sources

grep -q 'MixPilotRemoteProtocolVersion.supports(message.version)' \
  Sources/MixPilotRemoteBridge/MixPilotRemoteBridge.swift || {
    echo 'Architecture check failed: the Mac bridge does not validate the shared Remote protocol range' >&2
    exit 1
  }

grep -q 'MixPilotRemoteProtocolVersion.supports(message.version)' \
  Mobile/MixPilotRemote/Sources/RemoteConnection.swift || {
    echo 'Architecture check failed: the iPhone client does not validate the shared Remote protocol range' >&2
    exit 1
  }

grep -q 'applyingRuntimeAvailability' Sources/MixPilotApp/AppModel+Backend.swift || {
  echo 'Architecture check failed: preflight planning must apply current runtime permissions before confirming capabilities' >&2
  exit 1
}

grep -q 'coordinator.backendIdentifier == selectedBackend' Sources/MixPilotApp/AppModel+Live.swift || {
  echo 'Architecture check failed: Live must refuse a coordinator created for another backend before sending commands' >&2
  exit 1
}

grep -q 'startLiveReconciliation(expectedBackend:' Sources/MixPilotApp/AppModel+Live.swift || {
  echo 'Architecture check failed: Live must start periodic reconciliation for the active backend' >&2
  exit 1
}

grep -q 'try await Task.sleep(for: .seconds(5))' Sources/MixPilotApp/AppModel+Live.swift || {
  echo 'Architecture check failed: backend liveness must be checked periodically during Live' >&2
  exit 1
}

grep -q 'environment.isRunning' Sources/MixPilotApp/AppModel+Live.swift || {
  echo 'Architecture check failed: periodic Live reconciliation must detect a closed backend' >&2
  exit 1
}

grep -q 'state.isReliable' Sources/MixPilotApp/AppModel+Live.swift || {
  echo 'Architecture check failed: state contradictions may only trigger handoff when the backend marks the observation reliable' >&2
  exit 1
}

grep -q 'remoteActiveBackendIdentifier' Sources/MixPilotApp/AppModel+RemoteBridge.swift || {
  echo 'Architecture check failed: Remote snapshots must use the backend owned by the active Live coordinator' >&2
  exit 1
}

grep -q 'descriptor.capabilities.applyingRuntimeAvailability' Sources/MixPilotApp/AppModel+RemoteBridge.swift || {
  echo 'Architecture check failed: Remote controls must apply current runtime permissions to backend capabilities' >&2
  exit 1
}

grep -q 'remoteResumeRejectionReason' Sources/MixPilotApp/AppModel+RemoteBridge.swift || {
  echo 'Architecture check failed: Remote resume must actively revalidate the backend before asking the runtime to continue' >&2
  exit 1
}

grep -q 'backend.readState()' Sources/MixPilotApp/AppModel+RemoteBridge.swift || {
  echo 'Architecture check failed: Remote resume must read the current backend state' >&2
  exit 1
}

grep -q 'currentState.isReliable' Sources/MixPilotApp/AppModel+RemoteBridge.swift || {
  echo 'Architecture check failed: Remote resume must refuse an unverified deck state' >&2
  exit 1
}

if grep -n 'liveTask?.cancel()' Sources/MixPilotApp/AppModel+Live.swift; then
  echo 'Architecture check failed: manual control must use the coordinator safe-point handoff instead of cancelling the Live task first' >&2
  exit 1
fi

fail_if_found \
  'Button\("(Outils rekordbox|Inspecter rekordbox|Valider rekordbox commande par commande|Générer le mapping rekordbox|Configurer Serato)"' \
  'backend-specific tools must remain contextual and must not recreate a parallel global menu' \
  Sources/MixPilotApp/MixPilotApp.swift

if grep -RInE \
  --exclude='RemoteMappingUpdates.swift' \
  --exclude-dir=.build \
  --exclude-dir=.git \
  '^import CryptoKit$' Sources/MixPilotCore; then
  echo 'Architecture check failed: MixPilotCore must route hashing through the portable CryptoKit/Crypto adapter' >&2
  exit 1
fi

grep -q '#elseif canImport(Crypto)' Sources/MixPilotCore/RemoteMappingUpdates.swift || {
  echo 'Architecture check failed: portable Swift Crypto fallback is missing from MixPilotCore' >&2
  exit 1
}

grep -q 'NSLocalNetworkUsageDescription' Scripts/build_release.sh || {
  echo 'Architecture check failed: the packaged Mac app must declare local-network access for the iPhone Remote' >&2
  exit 1
}

grep -q '_mixpilot\._tcp' Scripts/build_release.sh || {
  echo 'Architecture check failed: the packaged Mac app must declare the MixPilot Bonjour service' >&2
  exit 1
}

grep -q '^  MixPilotRemoteTests:$' Mobile/MixPilotRemote/project.yml || {
  echo 'Architecture check failed: the iPhone project must include the application unit-test target' >&2
  exit 1
}

grep -q 'type: bundle.unit-test' Mobile/MixPilotRemote/project.yml || {
  echo 'Architecture check failed: MixPilotRemoteTests must remain an iOS unit-test bundle' >&2
  exit 1
}

grep -q 'target: MixPilotRemote' Mobile/MixPilotRemote/project.yml || {
  echo 'Architecture check failed: the iPhone unit tests must depend on the host application so XcodeGen configures TEST_HOST' >&2
  exit 1
}

test -f Mobile/MixPilotRemote/XcodeTests/RemoteConnectionTests.swift || {
  echo 'Architecture check failed: the iPhone application tests are missing' >&2
  exit 1
}

grep -q 'Run iOS application tests' .github/workflows/iphone-remote-ci.yml || {
  echo 'Architecture check failed: iPhone CI must execute the application test target on a simulator' >&2
  exit 1
}

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
