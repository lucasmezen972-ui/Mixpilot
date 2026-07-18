#!/usr/bin/env bash
set -euo pipefail

require() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  grep -qE "$pattern" "$file" || {
    echo "Transport reliability check failed: $message" >&2
    exit 1
  }
}

reject() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if grep -qE "$pattern" "$file"; then
    echo "Transport reliability check failed: $message" >&2
    exit 1
  fi
}

policy=Shared/RemoteProtocolV2/Sources/MixPilotRemoteProtocol/RemoteListenerRestartPolicy.swift
shared_security_policy=Shared/RemoteProtocolV2/Sources/MixPilotRemoteProtocol/RemoteTransportSecurityPolicy.swift
bridge=Sources/MixPilotRemoteBridge/MixPilotRemoteBridge.swift
security_policy=Sources/MixPilotRemoteBridge/RemoteTransportSecurityPolicy.swift
mac_app=Sources/MixPilotApp/MixPilotApp.swift
iphone=Mobile/MixPilotRemote/Sources/RemoteConnection.swift
iphone_discovery=Mobile/MixPilotRemote/Sources/BonjourDiscovery.swift

require 'struct RemoteTransportRetryPolicy' "$policy" 'shared bounded transport policy is missing'
require 'Remote(ListenerRestart|TransportRetry)Policy' "$bridge" 'Mac listener does not use the retry policy'
require 'scheduleRestart\(reason:' "$bridge" 'Mac listener failures do not schedule recovery'
require 'le Live local reste actif' "$bridge" 'Mac listener exhaustion must preserve the local Live'
require 'RemoteTransportRetryPolicy' "$iphone" 'iPhone reconnection is not bounded'
require 'transportGeneration' "$iphone" 'stale iPhone transport callbacks are not invalidated'
require 'lastSequence: lastSequence' "$iphone" 'iPhone reconnection does not resume snapshot sequencing'
require 'remote\.error\.reconnect_failed' "$iphone" 'iPhone retry exhaustion is not explicit through localized copy'
reject 'pendingCommand|queuedCommand|replayCommand' "$iphone" 'iPhone commands must never be queued for replay'

# P0 containment: the legacy ws transport may only exist behind one shared,
# Debug-only policy. Release builds on both platforms must remain fail-closed
# until authenticated TLS and device identity pinning replace this channel.
require '#if DEBUG' "$shared_security_policy" 'the shared insecure override is not limited to Debug builds'
require 'environment\[insecureDevelopmentOverrideKey\] == "1"' "$shared_security_policy" 'the shared insecure override is not explicit'
require '#else' "$shared_security_policy" 'the shared Release fail-closed branch is missing'
require 'false' "$shared_security_policy" 'Release builds do not fail closed for the insecure transport'
require 'MixPilotRemoteProtocol\.MixPilotRemoteTransportSecurityPolicy' "$security_policy" 'the Mac compatibility policy does not delegate to the shared gate'
require 'MixPilotRemoteTransportSecurityPolicy\.allowsCurrentDevelopmentTransport' "$mac_app" 'the Mac UI does not consult the Remote security policy'
require 'else if insecureRemoteDevelopmentOverrideEnabled' "$mac_app" 'the Mac listener start is not guarded by the development override'
require 'Ce transport local n’est pas encore chiffré' "$mac_app" 'the development-only warning does not disclose the unencrypted channel'
require 'allowsInsecureDevelopmentTransport' "$iphone_discovery" 'the iPhone does not guard insecure Bonjour discovery'

start_count="$(grep -c 'remoteBridge.start(provider: model)' "$mac_app" || true)"
if [[ "$start_count" -ne 1 ]]; then
  echo 'Transport reliability check failed: the Remote listener must have exactly one guarded start site' >&2
  exit 1
fi

echo 'Transport reliability consistency: OK'
