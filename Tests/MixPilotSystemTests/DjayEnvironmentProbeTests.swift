#if os(macOS)
import Testing
@testable import MixPilotSystem

@Test("djay process matcher accepts supported app names")
func acceptsDjayNames() {
    #expect(DjayApplicationMatcher.matches(name: "djay"))
    #expect(DjayApplicationMatcher.matches(name: "djay Pro"))
    #expect(DjayApplicationMatcher.matches(name: "djay Pro for Mac"))
}

@Test("djay process matcher rejects unrelated applications")
func rejectsOtherApplications() {
    #expect(!DjayApplicationMatcher.matches(name: "Serato DJ Pro"))
    #expect(!DjayApplicationMatcher.matches(name: "Spotify"))
    #expect(!DjayApplicationMatcher.matches(name: nil))
}
#endif
