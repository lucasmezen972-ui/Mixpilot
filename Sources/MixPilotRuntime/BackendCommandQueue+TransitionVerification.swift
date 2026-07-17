#if os(macOS)
import Foundation
import MixPilotCore

extension BackendCommandQueue: DJTransitionCommandSending {
    public func trigger(
        _ action: DJControlAction,
        requireVerification: Bool
    ) async throws {
        let expectedEffect: DJExpectedEffect = switch action {
        case .playA: .playback(true, deck: .a)
        case .playB: .playback(true, deck: .b)
        case .pauseA: .playback(false, deck: .a)
        case .pauseB: .playback(false, deck: .b)
        default: .stateChanged
        }

        _ = try await execute(
            DJBackendCommand(
                action: action,
                idempotencyKey: "transition|\(action.rawValue)|\(UUID().uuidString)"
            ),
            expectedEffect: expectedEffect,
            requireVerification: requireVerification
        )
    }
}
#endif
