import Foundation

public struct StrictVerificationDJBackend: DJBackend {
    private let base: any DJBackend

    public init(_ base: any DJBackend) {
        self.base = base
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
        try await base.readState()
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
