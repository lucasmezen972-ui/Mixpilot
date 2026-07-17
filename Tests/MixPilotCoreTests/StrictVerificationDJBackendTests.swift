import Foundation
import Testing
@testable import MixPilotCore

private struct VerificationFixtureBackend: DJBackend {
    let identifier: DJBackendIdentifier = .serato
    let displayName = "Fixture"
    let result: DJCommandVerification
    let state: DJBackendState = DJBackendState(isReliable: false)

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(identifier: identifier, isInstalled: true, isRunning: true)
    }

    func capabilities() async -> DJBackendCapabilities { DJBackendCapabilities() }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState { state }
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

private let validatedFixture = DJCommandVerification(
    status: .verified,
    confidence: .validated,
    detail: "confirmed"
)

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
        VerificationFixtureBackend(result: validatedFixture)
    )

    let result = try await backend.verify(
        command: DJBackendCommand(action: .playA),
        expectedEffect: .playback(true, deck: .a)
    )

    #expect(result.status == .verified)
    #expect(result.confidence == .validated)
}

@Test("Fresh reliable backend state is preserved")
func freshReliableBackendStateIsPreserved() async throws {
    let backend = StrictVerificationDJBackend(
        VerificationFixtureBackend(
            result: validatedFixture,
            state: DJBackendState(observedAt: Date(), isReliable: true)
        ),
        maximumStateAge: 2
    )

    let state = try await backend.readState()

    #expect(state.isReliable)
}

@Test("Stale reliable backend state is downgraded")
func staleReliableBackendStateIsDowngraded() async throws {
    let backend = StrictVerificationDJBackend(
        VerificationFixtureBackend(
            result: validatedFixture,
            state: DJBackendState(
                observedAt: Date().addingTimeInterval(-10),
                isReliable: true
            )
        ),
        maximumStateAge: 2
    )

    let state = try await backend.readState()

    #expect(!state.isReliable)
}
