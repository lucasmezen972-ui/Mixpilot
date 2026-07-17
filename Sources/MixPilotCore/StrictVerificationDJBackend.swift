import Foundation

public struct StrictVerificationDJBackend: DJBackend {
    private let base: any DJBackend
    private let maximumStateAge: TimeInterval

    public init(
        _ base: any DJBackend,
        maximumStateAge: TimeInterval = 2
    ) {
        self.base = base
        self.maximumStateAge = max(0, maximumStateAge)
    }

    public var identifier: DJBackendIdentifier { base.identifier }
    public var displayName: String { base.displayName }

    public func detectEnvironment() async -> DJBackendEnvironment {
        await base.detectEnvironment()
    }

    public func capabilities() async -> DJBackendCapabilities {
        await base.capabilities()
    }

    public func validateConfiguration() async -> DJBackendValidationReport {
        await base.validateConfiguration()
    }

    public func readState() async throws -> DJBackendState {
        var state = try await base.readState()
        if !state.isReliableAndFresh(maximumAge: maximumStateAge) {
            state.isReliable = false
        }
        return state
    }

    public func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        try await base.readDeckState(deck)
    }

    public func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        try await base.execute(command)
    }

    public func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        let result = try await base.verify(command: command, expectedEffect: expectedEffect)
        guard result.status == .verified, result.confidence == .validated else {
            return DJCommandVerification(
                status: result.status == .failed ? .failed : .unknown,
                confidence: result.confidence,
                detail: result.detail
            )
        }
        return result
    }

    public func takeManualControl() async {
        await base.takeManualControl()
    }
}
