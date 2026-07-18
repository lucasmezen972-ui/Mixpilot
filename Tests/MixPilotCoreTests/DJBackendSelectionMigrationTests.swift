@preconcurrency import Foundation
import Testing
@testable import MixPilotCore

@Test("A legacy DJ selection migrates once and removes the old key")
func legacySelectionMigratesOnce() async throws {
    let fixture = SelectionDefaultsFixture()
    defer { fixture.cleanup() }
    fixture.defaults.set("rekordbox", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: fixture.defaults)

    #expect(await store.loadSelection() == .rekordbox)
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.defaultsKey) == "rekordbox")
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

@Test("Clearing a migrated selection cannot resurrect the legacy value")
func clearedSelectionStaysCleared() async throws {
    let fixture = SelectionDefaultsFixture()
    defer { fixture.cleanup() }
    fixture.defaults.set("serato", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: fixture.defaults)

    #expect(await store.loadSelection() == .serato)
    try await store.saveSelection(nil)
    #expect(await store.loadSelection() == nil)
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.defaultsKey) == nil)
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

@Test("An invalid current preference is removed instead of falling back")
func invalidCurrentSelectionIsRemoved() async {
    let fixture = SelectionDefaultsFixture()
    defer { fixture.cleanup() }
    fixture.defaults.set("unknown-backend", forKey: MigratingDJBackendSelectionStore.defaultsKey)
    fixture.defaults.set("serato", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: fixture.defaults)

    #expect(await store.loadSelection() == nil)
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.defaultsKey) == nil)
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

@Test("Saving an explicit backend removes stale legacy data")
func explicitSelectionRemovesLegacyData() async throws {
    let fixture = SelectionDefaultsFixture()
    defer { fixture.cleanup() }
    fixture.defaults.set("serato", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: fixture.defaults)

    try await store.saveSelection(.djay)
    #expect(await store.loadSelection() == .djay)
    #expect(fixture.defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

private struct SelectionDefaultsFixture {
    let suiteName = "MixPilotSelectionTests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
