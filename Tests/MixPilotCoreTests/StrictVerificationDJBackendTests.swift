import Testing
@testable import MixPilotCore

private struct VerificationFixtureBackend: DJBackend {
    let identifier: DJBackendIdentifier = .serato
    let displayName = "Fixture"
    let result: DJCommandVerification

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true)
    }

    func capabilities() async -> DJBackendCapabilities { DJBackendCapabilities() }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState { DJBackendState(isReliable: false) }
    func readDeckState(_ deck: DeckID) async throws -> DJDeckState { DJDeckState(deck: deck) }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        DJCommandReceipt(commandID: command.id, status: .acknowledged)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        result
    }

    func takeManualControl() async {}
}

@Test("Observed verification is downgraded")
func observedVerificationIsDowngraded() async throws {
    let backend = StrictVerificationDJBackend(
        VerificationFixtureBackend(
            result: DJCommandVerification(
                status: .observed,
                confidence: .observed,
                detail: "visible"
            )
        )
    )

    let result = try await backend.verify(
        command: DJBackendCommand(action: .loadA),
        expectedEffect: .stateChanged
    )

    #expect(result.status == .unknown)
    #expect(result.confidence == .observed)
}

@Test("Weak verified confidence is downgraded")
func weakVerifiedConfidenceIsDowngraded() async throws {
    let backend = StrictVerificationDJBackend(
        VerificationFixtureBackend(
            result: DJCommandVerification(
                status: .verified,
                confidence: .observed,
                detail: "weak"
            )
        )
    )

    let result = try await backend.verify(
        command: DJBackendCommand(action: .playA),
        expectedEffect: .playback(true, deck: .a)
    )

    #expect(result.status == .unknown)
}

@Test("Validated verification is preserved")
func validatedVerificationIsPreserved() async throws {
    let backend = StrictVerificationDJBackend(
        VerificationFixtureBackend(
            result: DJCommandVerification(
                status: .verified,
                confidence: .validated,
                detail: "confirmed"
            )
        )
    )

    let result = try await backend.verify(
        command: DJBackendCommand(action: .playA),
        expectedEffect: .playback(true, deck: .a)
    )

    #expect(result.status == .verified)
    #expect(result.confidence == .validated)
}
