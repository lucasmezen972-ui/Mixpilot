import Foundation
import Testing
@testable import MixPilotCore

@Test("The registry starts without inventing a backend")
func registryDoesNotDefaultToSerato() async {
    let store = InMemoryDJBackendSelectionStore()
    let registry = DJBackendRegistry(
        backends: [
            FullyCapableBackend(identifier: .djay),
            FullyCapableBackend(identifier: .rekordbox),
            FullyCapableBackend(identifier: .serato)
        ],
        selectionStore: store
    )

    #expect(await registry.selectedBackend() == nil)

    do {
        _ = try await registry.activeBackend()
        Issue.record("The registry should require an explicit selection.")
    } catch let error as DJBackendError {
        guard case .notSelected = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("A selected backend is persisted and restored")
func registryPersistsSelection() async throws {
    let store = InMemoryDJBackendSelectionStore()
    let backends: [any DJBackend] = [
        FullyCapableBackend(identifier: .djay),
        FullyCapableBackend(identifier: .rekordbox),
        FullyCapableBackend(identifier: .serato)
    ]

    let firstRegistry = DJBackendRegistry(backends: backends, selectionStore: store)
    try await firstRegistry.select(.djay)
    #expect(await firstRegistry.selectedBackend() == .djay)

    let restoredRegistry = DJBackendRegistry(backends: backends, selectionStore: store)
    #expect(await restoredRegistry.selectedBackend() == .djay)
    #expect(try await restoredRegistry.activeBackend().identifier == .djay)
}

@Test("Changing backend is blocked while Live is active")
func registryBlocksBackendChangeDuringLive() async throws {
    let registry = DJBackendRegistry(
        backends: [
            FullyCapableBackend(identifier: .djay),
            FullyCapableBackend(identifier: .rekordbox)
        ],
        selectionStore: InMemoryDJBackendSelectionStore(identifier: .djay)
    )

    await registry.setLiveActive(true)

    do {
        try await registry.select(.rekordbox)
        Issue.record("A backend change must be refused during Live.")
    } catch let error as DJBackendError {
        guard case .liveChangeForbidden = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    }

    #expect(await registry.selectedBackend() == .djay)
}

@Test("Backend descriptors expose all official backends at the same level")
func registryListsOfficialBackends() async {
    let registry = DJBackendRegistry(
        backends: [
            FullyCapableBackend(identifier: .djay),
            PartialBackend(identifier: .rekordbox),
            FullyCapableBackend(identifier: .serato)
        ],
        selectionStore: InMemoryDJBackendSelectionStore()
    )

    let descriptors = await registry.availableBackends()
    #expect(Set(descriptors.map(\.identifier)) == Set(DJBackendIdentifier.allCases))
    #expect(descriptors.allSatisfy { $0.environment.isInstalled })
}

@Test("A partial backend reports unavailable capabilities instead of inventing them")
func partialBackendNegotiatesCapabilities() async {
    let backend = PartialBackend()
    let capabilities = await backend.capabilities()

    #expect(capabilities.supports(.playPause))
    #expect(capabilities.supports(.channelVolume))
    #expect(!capabilities.supports(.crossfader))
    #expect(!capabilities.supports(.effects))
    #expect(capabilities[.crossfader].validation == .blockedByPlatform)
}

@Test("A read-only backend refuses control commands")
func readOnlyBackendRejectsCommands() async {
    let backend = ReadOnlyBackend()
    let command = DJBackendCommand(action: .playA)

    do {
        _ = try await backend.execute(command)
        Issue.record("A read-only backend must reject control commands.")
    } catch let error as DJBackendError {
        guard case .commandRejected = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("A disconnected backend reports a human-readable failure")
func disconnectedBackendFailsSafely() async {
    let backend = DisconnectedBackend(identifier: .rekordbox)

    do {
        _ = try await backend.readState()
        Issue.record("A disconnected backend must not return a fictional state.")
    } catch let error as DJBackendError {
        guard case .disconnected(.rekordbox) = error else {
            Issue.record("Unexpected error: \(error)")
            return
        }
        #expect(error.localizedDescription.contains("rekordbox"))
        #expect(error.localizedDescription.contains("Reprends la main"))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test("Command receipts distinguish acknowledgement from verification")
func commandLifecycleIsExplicit() async throws {
    let backend = FullyCapableBackend(identifier: .serato)
    let command = DJBackendCommand(action: .playA)

    let receipt = try await backend.execute(command)
    #expect(receipt.status == .acknowledged)

    let verification = try await backend.verify(
        command: command,
        expectedEffect: .playback(true, deck: .a)
    )
    #expect(verification.status == .verified)
}
