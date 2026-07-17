import Foundation
import Testing
@testable import MixPilotCore

@Test("A legacy DJ selection migrates once and removes the old key")
func legacySelectionMigratesOnce() async throws {
    let defaults = testDefaults()
    defer { clear(defaults) }
    defaults.set("rekordbox", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: defaults)

    #expect(await store.loadSelection() == .rekordbox)
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.defaultsKey) == "rekordbox")
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

@Test("Clearing a migrated selection cannot resurrect the legacy value")
func clearedSelectionStaysCleared() async throws {
    let defaults = testDefaults()
    defer { clear(defaults) }
    defaults.set("serato", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: defaults)

    #expect(await store.loadSelection() == .serato)
    try await store.saveSelection(nil)
    #expect(await store.loadSelection() == nil)
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.defaultsKey) == nil)
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

@Test("An invalid current preference is removed instead of falling back")
func invalidCurrentSelectionIsRemoved() async {
    let defaults = testDefaults()
    defer { clear(defaults) }
    defaults.set("unknown-backend", forKey: MigratingDJBackendSelectionStore.defaultsKey)
    defaults.set("serato", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: defaults)

    #expect(await store.loadSelection() == nil)
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.defaultsKey) == nil)
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

@Test("Saving an explicit backend removes stale legacy data")
func explicitSelectionRemovesLegacyData() async throws {
    let defaults = testDefaults()
    defer { clear(defaults) }
    defaults.set("serato", forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey)
    let store = MigratingDJBackendSelectionStore(defaults: defaults)

    try await store.saveSelection(.djay)
    #expect(await store.loadSelection() == .djay)
    #expect(defaults.string(forKey: MigratingDJBackendSelectionStore.legacyDefaultsKey) == nil)
}

private func testDefaults() -> UserDefaults {
    UserDefaults(suiteName: "MixPilotSelectionTests-\(UUID().uuidString)")!
}

private func clear(_ defaults: UserDefaults) {
    if let suite = defaults.volatileDomainNames.first(where: { $0.hasPrefix("MixPilotSelectionTests-") }) {
        defaults.removePersistentDomain(forName: suite)
    }
}
