#if os(macOS)
import Testing
@testable import MixPilotSystem

@Test("rekordbox matcher accepts supported app names")
func acceptsRekordboxNames() {
    #expect(RekordboxApplicationMatcher.matches(name: "rekordbox"))
    #expect(RekordboxApplicationMatcher.matches(name: "rekordbox 7"))
    #expect(RekordboxApplicationMatcher.matches(name: "rekordbox Performance"))
}

@Test("rekordbox matcher accepts bundle identifiers containing rekordbox")
func acceptsRekordboxBundles() {
    #expect(RekordboxApplicationMatcher.matches(
        name: "AlphaTheta DJ Application",
        bundleIdentifier: "com.alphatheta.rekordbox"
    ))
    #expect(RekordboxApplicationMatcher.matches(
        name: nil,
        bundleIdentifier: "com.pioneerdj.rekordboxdj"
    ))
}

@Test("rekordbox matcher rejects unrelated applications")
func rejectsOtherApplicationsForRekordbox() {
    #expect(!RekordboxApplicationMatcher.matches(name: "Serato DJ Pro"))
    #expect(!RekordboxApplicationMatcher.matches(name: "djay Pro"))
    #expect(!RekordboxApplicationMatcher.matches(name: nil, bundleIdentifier: nil))
}
#endif
