#!/usr/bin/env bash
set -euo pipefail

require_file() {
  test -f "$1" || {
    echo "Runtime safety check failed: missing $1" >&2
    exit 1
  }
}

require_pattern() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  grep -qE "$pattern" "$file" || {
    echo "Runtime safety check failed: $message" >&2
    exit 1
  }
}

require_file Sources/MixPilotCore/StrictVerificationDJBackend.swift
require_file Tests/MixPilotCoreTests/StrictVerificationDJBackendTests.swift
require_file Tests/MixPilotRuntimeTests/BackendCommandQueueSafetyTests.swift
require_file Tests/MixPilotRuntimeTests/BackendCommandCadenceTests.swift
require_file Tests/MixPilotRuntimeTests/TransitionTriggerVerificationTests.swift
require_file Tests/MixPilotRuntimeTests/TransitionFrameCoalescingTests.swift
require_file Sources/MixPilotCore/MIDIMappingRuntimeCompatibility.swift
require_file Tests/MixPilotCoreTests/MIDIMappingRuntimeCompatibilityTests.swift
require_file Tests/MixPilotCoreTests/AudioWatchdogStateTests.swift
require_file Tests/MixPilotSystemTests/EmergencyAudioPlayerTests.swift

require_pattern 'StrictVerificationDJBackend' Sources/MixPilotApp/AppModel+Mapping.swift \
  'active backends must use the strict verification boundary'
require_pattern 'verification\.status == \.verified' Sources/MixPilotRuntime/BackendCommandQueue.swift \
  'critical commands must require verified evidence'
require_pattern 'verification\.confidence == \.validated' Sources/MixPilotRuntime/BackendCommandQueue.swift \
  'critical commands must require validated confidence'
require_pattern 'attemptVerification: false' Sources/MixPilotRuntime/BackendCommandQueue.swift \
  'continuous automation must avoid per-frame state inspection'
require_pattern 'ContinuousClock\(\)' Sources/MixPilotCore/TransitionRuntime.swift \
  'transition timing must use a monotonic clock'
require_pattern 'quantizationStep = 1\.0 / 127\.0' Sources/MixPilotCore/TransitionRuntime.swift \
  'transition values must be coalesced at MIDI resolution'
require_pattern 'requireVerification: false' Sources/MixPilotCore/TransitionRuntime.swift \
  'Sync must remain best effort until a structured verifier exists'
require_pattern 'requireVerification: true' Sources/MixPilotCore/TransitionRuntime.swift \
  'Play and Pause must keep immediate verification'
require_pattern 'momentaryPulseDuration' Sources/MixPilotMIDI/MappedSeratoController.swift \
  'momentary MIDI controls need a stable pulse duration'
require_pattern 'continuousActionRequiresControlChange' Sources/MixPilotMIDI/MappedSeratoController.swift \
  'continuous actions must reject Note mappings'
require_pattern 'hasRuntimeCompatibleMapping' Sources/MixPilotCore/MIDIMappingFingerprint.swift \
  'mapping coverage must count compatible mappings only'
require_pattern 'AudioWatchdogEvent\?' Sources/MixPilotCore/AudioWatchdog.swift \
  'watchdog notifications must be edge triggered'
require_pattern 'audioMonitoringGeneration' Sources/MixPilotApp/AppModel.swift \
  'audio monitoring needs a session generation'
require_pattern 'audioMonitoringGeneration == generation' Sources/MixPilotApp/AppModel+Preparation.swift \
  'stale audio callbacks must be ignored'
require_pattern 'sample\.timestamp - self\.lastAudioLevelUIUpdateAt >= 0\.1' Sources/MixPilotApp/AppModel+Preparation.swift \
  'audio level UI updates must be throttled'
require_pattern 'takeManualControl\(\)' Sources/MixPilotApp/AppModel+Preparation.swift \
  'critical audio incidents must hand control back'
require_pattern 'operationGeneration' Sources/MixPilotSystem/EmergencyAudioPlayer.swift \
  'stale emergency-player fades must be invalidated'

echo 'Runtime safety consistency: OK'
