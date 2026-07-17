import Foundation
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
func missingLegacyPreferenceReturnsNil() {
    let defaults = UserDefaults.standard
    let previous = defaults.string(forKey: DJSoftwareSelectionStore.defaultsKey)
    defer {
        if let previous {
            defaults.set(previous, forKey: DJSoftwareSelectionStore.defaultsKey)
        } else {
            defaults.removeObject(forKey: DJSoftwareSelectionStore.defaultsKey)
        }
    }

    defaults.removeObject(forKey: DJSoftwareSelectionStore.defaultsKey)
    #expect(DJSoftwareSelectionStore.selected == nil)
    #expect(DJSoftwareSelectionStore.migrateToBackendIdentifier() == nil)
}

@Test("An explicit legacy preference migrates without changing its backend")
func explicitLegacyPreferenceMigrates() {
    let defaults = UserDefaults.standard
    let previous = defaults.string(forKey: DJSoftwareSelectionStore.defaultsKey)
    defer {
        if let previous {
            defaults.set(previous, forKey: DJSoftwareSelectionStore.defaultsKey)
        } else {
            defaults.removeObject(forKey: DJSoftwareSelectionStore.defaultsKey)
        }
    }

    DJSoftwareSelectionStore.selected = .rekordbox
    #expect(DJSoftwareSelectionStore.migrateToBackendIdentifier() == .rekordbox)
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
