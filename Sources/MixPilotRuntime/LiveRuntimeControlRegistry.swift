#if os(macOS)
import Combine
import Foundation
import MixPilotCore

@MainActor
public final class LiveRuntimeControlMirror: ObservableObject {
    public static let shared = LiveRuntimeControlMirror()

    @Published public private(set) var phase: LiveRuntimePhase = .idle
    @Published public private(set) var pausedFromPhase: LiveRuntimePhase?
    @Published public private(set) var incomingTrackVerified = false
    @Published public private(set) var message = "Autopilot inactif"

    private init() {}

    public func update(
        phase: LiveRuntimePhase,
        pausedFromPhase: LiveRuntimePhase?,
        incomingTrackVerified: Bool,
        message: String
    ) {
        self.phase = phase
        self.pausedFromPhase = pausedFromPhase
        self.incomingTrackVerified = incomingTrackVerified
        self.message = message
    }
}

public actor LiveRuntimeCoordinatorRegistry {
    public static let shared = LiveRuntimeCoordinatorRegistry()

    private var coordinator: LiveAutopilotCoordinator?

    private init() {}

    public func attach(_ coordinator: LiveAutopilotCoordinator) {
        self.coordinator = coordinator
    }

    public func detach(_ coordinator: LiveAutopilotCoordinator) {
        if self.coordinator === coordinator {
            self.coordinator = nil
        }
    }

    public func requestPause() async -> LiveRuntimeCommandDecision {
        guard let coordinator else {
            return .reject("Le coordinateur Live n’est pas disponible.")
        }
        return await coordinator.requestPause()
    }

    public func requestResume(
        midiReady: Bool,
        audioWatchdogReady: Bool
    ) async -> LiveRuntimeCommandDecision {
        guard let coordinator else {
            return .reject("Le coordinateur Live n’est pas disponible.")
        }
        return await coordinator.requestResume(
            midiReady: midiReady,
            audioWatchdogReady: audioWatchdogReady
        )
    }

    public func requestSkipTransition() async -> LiveRuntimeCommandDecision {
        guard let coordinator else {
            return .reject("Le coordinateur Live n’est pas disponible.")
        }
        return await coordinator.requestSkipTransition()
    }

    public func requestManualControl() async -> LiveRuntimeCommandDecision {
        guard let coordinator else {
            return .reject("Le coordinateur Live n’est pas disponible.")
        }
        return await coordinator.requestManualControl()
    }
}
#endif
