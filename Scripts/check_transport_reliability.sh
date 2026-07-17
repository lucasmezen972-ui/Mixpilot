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
bridge=Sources/MixPilotRemoteBridge/MixPilotRemoteBridge.swift
iphone=Mobile/MixPilotRemote/Sources/RemoteConnection.swift

require 'struct RemoteTransportRetryPolicy' "$policy" 'shared bounded transport policy is missing'
require 'RemoteListenerRestartPolicy' "$bridge" 'Mac listener does not use the retry policy'
require 'scheduleRestart\(reason:' "$bridge" 'Mac listener failures do not schedule recovery'
require 'le Live local reste actif' "$bridge" 'Mac listener exhaustion must preserve the local Live'
require 'RemoteTransportRetryPolicy' "$iphone" 'iPhone reconnection is not bounded'
require 'transportGeneration' "$iphone" 'stale iPhone transport callbacks are not invalidated'
require 'lastSequence: lastSequence' "$iphone" 'iPhone reconnection does not resume snapshot sequencing'
require 'La reconnexion automatique a échoué' "$iphone" 'iPhone retry exhaustion is not explicit'
reject 'pendingCommand|queuedCommand|replayCommand' "$iphone" 'iPhone commands must never be queued for replay'

echo 'Transport reliability consistency: OK'
