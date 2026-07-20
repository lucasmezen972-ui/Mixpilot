import Foundation
import Testing
@testable import MixPilotCore

@Test("Duplicate command validations use the latest record without trapping")
func duplicateCommandValidationsUseLatestRecord() async {
    let context = DJValidationPlatformContext(
        operatingSystemVersion: "macOS-test",
        hardwareModel: "Mac-test",
        appBuild: "build-test"
    )
    let key = DJCommandValidationKey(
        backend: .serato,
        softwareVersion: "4.0",
        controllerName: "MixPilot Virtual Controller",
        mappingVersion: "profile-1",
        action: .playA,
        platformContext: context
    )
    let first = DJCommandValidationRecord(
        key: key,
        status: .failed,
        evidence: .userRejected,
        detail: "first"
    )
    let latest = DJCommandValidationRecord(
        key: key,
        status: .automatedSuccess,
        evidence: .deviceConfirmed,
        detail: "latest"
    )

    let store = InMemoryDJCommandValidationStore(records: [first, latest])
    let loaded = await store.validation(for: key)

    #expect(loaded == latest)
}

@Test("Telemetry payload normalization resolves duplicate safe keys deterministically")
func telemetryPayloadNormalizationHandlesCollisions() {
    let event = MixPilotTelemetryEvent(
        category: "repository",
        name: "collision",
        payload: [
            "foo_bar": "second",
            "foo-bar": "first",
        ]
    )

    #expect(event.payload == ["foo_bar": "first"])
}

@Test("Duplicate backend identifiers use the last registered implementation")
func duplicateBackendsUseLastRegistration() async {
    let registry = DJBackendRegistry(
        backends: [
            HardeningTestBackend(identifier: .serato, displayName: "first"),
            HardeningTestBackend(identifier: .serato, displayName: "latest"),
        ],
        selectionStore: InMemoryDJBackendSelectionStore()
    )

    let descriptors = await registry.availableBackends()

    #expect(descriptors.count == 1)
    #expect(descriptors.first?.identifier == .serato)
    #expect(descriptors.first?.displayName == "latest")
}

private struct HardeningTestBackend: DJBackend {
    let identifier: DJBackendIdentifier
    let displayName: String

    func detectEnvironment() async -> DJBackendEnvironment {
        DJBackendEnvironment(
            identifier: identifier,
            isInstalled: true,
            isRunning: true,
            softwareVersion: "test"
        )
    }

    func capabilities() async -> DJBackendCapabilities {
        DJBackendCapabilities()
    }

    func validateConfiguration() async -> DJBackendValidationReport {
        DJBackendValidationReport(backend: identifier, items: [])
    }

    func readState() async throws -> DJBackendState {
        DJBackendState(isReliable: true)
    }

    func readDeckState(_ deck: DeckID) async throws -> DJDeckState {
        DJDeckState(deck: deck)
    }

    func execute(_ command: DJBackendCommand) async throws -> DJCommandReceipt {
        DJCommandReceipt(commandID: command.id, status: .sent)
    }

    func verify(
        command: DJBackendCommand,
        expectedEffect: DJExpectedEffect
    ) async throws -> DJCommandVerification {
        DJCommandVerification(
            status: .verified,
            confidence: .validated,
            detail: "test"
        )
    }

    func takeManualControl() async {}
}
