#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotSystem

@Test("Online services serialize the actual selected backend")
func cloudContextUsesDynamicBackend() throws {
    for backend in DJBackendIdentifier.allCases {
        var capabilities = DJBackendCapabilities()
        capabilities[.playPause] = DJCapabilityStatus(
            availability: .available,
            confidence: .validated,
            validation: .automatedSuccess,
            method: .coreMIDI,
            testedSoftwareVersion: "test"
        )
        let context = MixPilotCloudBackendContext(
            identifier: backend,
            softwareVersion: "7.1",
            controllerName: "MixPilot Virtual Controller",
            mappingVersion: "12",
            mappingSHA256: String(repeating: "a", count: 64),
            capabilities: capabilities,
            validationStatus: "ready"
        )

        let data = try JSONEncoder().encode(context)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["identifier"] as? String == backend.rawValue)
        #expect(object["softwareVersion"] as? String == "7.1")
        #expect(object["mappingVersion"] as? String == "12")
        #expect((object["capabilities"] as? [String: Any])?["playPause"] != nil)
    }
}

@Test("Online diagnostics remain disabled until the user opts in")
func diagnosticsAreOptIn() {
    let suiteName = "MixPilotCloudPreferencesTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Unable to create isolated UserDefaults suite")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var preferences = MixPilotOnlineDiagnosticsPreferences(defaults: defaults)
    #expect(!preferences.isEnabled)

    preferences.isEnabled = true
    #expect(preferences.isEnabled)
}
#endif
