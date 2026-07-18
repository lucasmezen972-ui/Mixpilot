@preconcurrency import Foundation
import Testing
@testable import MixPilotCore

@Test("Legacy software identifiers map to the common backend identifiers")
func legacySoftwareMapsToBackendIdentifier() {
    #expect(DJSoftware.serato.backendIdentifier == .serato)
    #expect(DJSoftware.djay.backendIdentifier == .djay)
    #expect(DJSoftware.rekordbox.backendIdentifier == .rekordbox)
    #expect(DJSoftware(.djay) == .djay)
}

@Test("A missing legacy preference does not invent Serato")
func missingLegacyPreferenceReturnsNil() async {
    let suiteName = "MixPilotTests.MissingLegacy.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = UserDefaultsDJBackendSelectionStore(defaults: defaults)

    #expect(await store.loadSelection() == nil)
    #expect(defaults.string(forKey: UserDefaultsDJBackendSelectionStore.defaultsKey) == nil)
}

@Test("An explicit legacy preference migrates without changing its backend")
func explicitLegacyPreferenceMigrates() async {
    let suiteName = "MixPilotTests.ExplicitLegacy.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(
        DJSoftware.rekordbox.rawValue,
        forKey: UserDefaultsDJBackendSelectionStore.legacyDefaultsKey
    )
    let store = UserDefaultsDJBackendSelectionStore(defaults: defaults)

    #expect(await store.loadSelection() == .rekordbox)
    #expect(
        defaults.string(forKey: UserDefaultsDJBackendSelectionStore.defaultsKey) ==
            DJBackendIdentifier.rekordbox.rawValue
    )
}

@Test("Simulation and pending device validation never confirm a Live capability")
func strictLiveCapabilityValidation() {
    let simulated = DJCapabilityStatus(
        availability: .available,
        confidence: .simulated,
        validation: .simulatedSuccess
    )
    let pendingDevice = DJCapabilityStatus(
        availability: .available,
        confidence: .observed,
        validation: .requiresDeviceValidation
    )
    let confirmed = DJCapabilityStatus(
        availability: .available,
        confidence: .validated,
        validation: .automatedSuccess
    )

    #expect(!simulated.isConfirmedForLive)
    #expect(!pendingDevice.isConfirmedForLive)
    #expect(confirmed.isConfirmedForLive)
}
