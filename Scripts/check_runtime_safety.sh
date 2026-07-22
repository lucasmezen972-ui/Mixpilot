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

reject_pattern() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if grep -qE "$pattern" "$file"; then
    echo "Runtime safety check failed: $message" >&2
    exit 1
  fi
}

require_file Sources/MixPilotCore/StrictVerificationDJBackend.swift
require_file Tests/MixPilotCoreTests/StrictVerificationDJBackendTests.swift
require_file Sources/MixPilotCore/DJBackendStateFreshness.swift
require_file Tests/MixPilotCoreTests/DJBackendStateFreshnessTests.swift
require_file Tests/MixPilotRuntimeTests/BackendCommandQueueSafetyTests.swift
require_file Tests/MixPilotRuntimeTests/BackendCommandCadenceTests.swift
require_file Tests/MixPilotRuntimeTests/TransitionTriggerVerificationTests.swift
require_file Tests/MixPilotRuntimeTests/TransitionFrameCoalescingTests.swift
require_file Sources/MixPilotCore/MIDIMappingRuntimeCompatibility.swift
require_file Tests/MixPilotCoreTests/MIDIMappingRuntimeCompatibilityTests.swift
require_file Tests/MixPilotCoreTests/AudioWatchdogStateTests.swift
require_file Tests/MixPilotSystemTests/EmergencyAudioPlayerTests.swift
require_file Tests/MixPilotCoreTests/LiveCheckpointMigrationTests.swift
require_file Sources/MixPilotCore/BoundedBackoffPolicy.swift
require_file Tests/MixPilotCoreTests/BoundedBackoffPolicyTests.swift
require_file Shared/RemoteProtocolV2/Sources/MixPilotRemoteProtocol/RemoteListenerRestartPolicy.swift
require_file Shared/RemoteProtocolV2/Tests/MixPilotRemoteProtocolTests/RemoteListenerRestartPolicyTests.swift

require_pattern 'StrictVerificationDJBackend' Sources/MixPilotApp/AppModel+Mapping.swift \
  'active backends must use the strict verification boundary'
require_pattern 'isReliableAndFresh' Sources/MixPilotCore/StrictVerificationDJBackend.swift \
  'the strict backend boundary must reject stale state'
require_pattern 'age >= 0' Sources/MixPilotCore/DJBackendStateFreshness.swift \
  'future-dated backend observations must not be accepted'
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
require_pattern 'let baseIndex = currentIndex' Sources/MixPilotSystem/EmergencyAudioPlayer.swift \
  'emergency fallback order must remain stable across failed candidates'
require_pattern 'invalidPaths' Sources/MixPilotSystem/EmergencyAudioPlayer.swift \
  'known-bad emergency files must not be retried in a loop'
require_pattern 'decision: \.requireManualConfirmation' Sources/MixPilotCore/LiveCheckpoint.swift \
  'crash recovery must require confirmation on the Mac'
reject_pattern 'decision: \.resumeAutomatically' Sources/MixPilotCore/LiveCheckpoint.swift \
  'crash recovery must never restart the Live automatically'

require_pattern 'Remote(ListenerRestart|TransportRetry)Policy' Sources/MixPilotRemoteBridge/MixPilotRemoteBridge.swift \
  'the Remote listener needs a bounded restart policy'
require_pattern 'scheduleRestart\(reason:' Sources/MixPilotRemoteBridge/MixPilotRemoteBridge.swift \
  'listener failures must schedule a bounded restart instead of stopping the Live'
require_pattern 'le Live local reste actif' Sources/MixPilotRemoteBridge/MixPilotRemoteBridge.swift \
  'Remote exhaustion must state that the local Live remains active'
require_pattern 'AVAudioEngineConfigurationChange' Sources/MixPilotSystem/AudioLevelMonitor.swift \
  'audio route and format changes must be observed explicitly'
require_pattern 'BoundedBackoffPolicy' Sources/MixPilotSystem/AudioLevelMonitor.swift \
  'audio monitor restarts must have a bounded retry budget'
require_pattern 'generation == self\.generation' Sources/MixPilotSystem/AudioLevelMonitor.swift \
  'buffers from an obsolete audio-engine generation must be ignored'
require_pattern 'recoveryQueue' Sources/MixPilotSystem/AudioLevelMonitor.swift \
  'audio engine reconstruction must happen outside the framework callback'

reject_pattern 'signInAnonymously' Sources/MixPilotSystem/MixPilotCloudService.swift \
  'the cloud service must never recreate anonymous sessions'
reject_pattern 'signInAnonymously' Sources/MixPilotSystem/MixPilotRemoteMappingService.swift \
  'remote mapping discovery must never recreate anonymous sessions'
require_pattern 'guard supabase\.auth\.currentSession != nil' Sources/MixPilotSystem/MixPilotCloudService.swift \
  'cloud operations must fail closed while signed out'
require_pattern 'guard supabase\.auth\.currentSession != nil' Sources/MixPilotSystem/MixPilotRemoteMappingService.swift \
  'remote mapping discovery must fail closed while signed out'
require_pattern 'catch let error as MixPilotCloudIdentityError where error == \.signedOut' Sources/MixPilotApp/MixPilotCloudCoordinator.swift \
  'the cloud loop must handle explicit signed-out state'
require_pattern 'try await Task\.sleep\(for: \.seconds\(30\)\)' Sources/MixPilotApp/MixPilotCloudCoordinator.swift \
  'signed-out polling must remain paced instead of retrying in a tight loop'
require_pattern 'catch MixPilotCloudError\.authenticationUnavailable' Sources/MixPilotApp/MixPilotCloudCoordinator.swift \
  'the cloud loop must stop when server-side authentication is intentionally disabled'

echo 'Runtime safety consistency: OK'
