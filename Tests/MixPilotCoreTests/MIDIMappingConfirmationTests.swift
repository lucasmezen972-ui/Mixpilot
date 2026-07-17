import Foundation
import Testing
@testable import MixPilotCore

@Suite(.serialized)
struct MIDIMappingConfirmationTests {
    @Test("Configured MIDI messages remain unready until confirmed")
    func confirmationRequired() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: MIDIMappingProfile.confirmationDefaultsKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: MIDIMappingProfile.confirmationDefaultsKey)
            } else {
                defaults.removeObject(forKey: MIDIMappingProfile.confirmationDefaultsKey)
            }
        }

        defaults.removeObject(forKey: MIDIMappingProfile.confirmationDefaultsKey)
        let profile = MIDIMappingProfile.developmentDefault
        #expect(profile.configuredRatio == 1)
        #expect(profile.confirmationRatio == 0)
        #expect(profile.completionRatio == 0)

        let confirmations = Dictionary(uniqueKeysWithValues: SeratoAction.allCases.map { ($0.rawValue, true) })
        defaults.set(confirmations, forKey: MIDIMappingProfile.confirmationDefaultsKey)
        #expect(profile.confirmationRatio == 1)
        #expect(profile.completionRatio == 1)
    }
}
