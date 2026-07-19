import Foundation
import Testing
@testable import MixPilotSystem

@Test("Serato matcher accepts the official app and rejects crash helpers")
func seratoMatcherRejectsCrashHelpers() {
    #expect(SeratoApplicationMatcher.matches(
        name: "Serato DJ Pro",
        bundleIdentifier: "com.serato.seratodj",
        bundleURL: URL(fileURLWithPath: "/Applications/Serato DJ Pro.app")
    ))
    #expect(!SeratoApplicationMatcher.matches(
        name: "Serato DJ Pro",
        bundleIdentifier: "com.googlecode.crashpad.popup",
        bundleURL: URL(fileURLWithPath: "/Applications/Serato DJ Pro.app/Contents/MacOS/crashpad_popup.app")
    ))
}
