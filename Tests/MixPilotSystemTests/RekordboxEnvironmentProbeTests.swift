#if os(macOS)
import Foundation
import Testing
@testable import MixPilotSystem

@Test("rekordbox matcher accepts supported app names")
func acceptsRekordboxNames() {
    #expect(RekordboxApplicationMatcher.matches(name: "rekordbox"))
    #expect(RekordboxApplicationMatcher.matches(name: "rekordbox 6"))
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

@Test("rekordbox matcher accepts versioned bundle paths")
func acceptsVersionedRekordboxPaths() throws {
    let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
    let versionSeven = applications
        .appendingPathComponent("rekordbox 7", isDirectory: true)
        .appendingPathComponent("rekordbox.app", isDirectory: true)
    let versionSix = applications
        .appendingPathComponent("rekordbox 6", isDirectory: true)
        .appendingPathComponent("rekordbox.app", isDirectory: true)

    #expect(RekordboxApplicationMatcher.matches(name: nil, bundleURL: versionSeven))
    #expect(RekordboxApplicationMatcher.matches(name: nil, bundleURL: versionSix))
    #expect(RekordboxApplicationMatcher.majorVersionHint(
        name: "rekordbox 7",
        bundleURL: versionSeven
    ) == 7)
    #expect(RekordboxApplicationMatcher.majorVersionHint(
        name: "rekordbox 6",
        bundleURL: versionSix
    ) == 6)
}

@Test("rekordbox installation locator scans Applications and versioned folders")
func locatesRekordboxInStandardAndVersionedFolders() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let direct = root.appendingPathComponent("rekordbox.app", isDirectory: true)
    let versioned = root
        .appendingPathComponent("rekordbox 7", isDirectory: true)
        .appendingPathComponent("rekordbox.app", isDirectory: true)
    try FileManager.default.createDirectory(at: direct, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: versioned, withIntermediateDirectories: true)

    let discovered = RekordboxInstallationLocator.discoverApplicationURLs(
        searchRoots: [root]
    )

    #expect(Set(discovered) == Set([
        direct.standardizedFileURL,
        versioned.standardizedFileURL,
    ]))
}

@Test("rekordbox standard roots include user Applications")
func standardRootsIncludeUserApplications() {
    let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
    let roots = RekordboxInstallationLocator.standardSearchRoots(homeDirectory: home)

    #expect(roots.contains(URL(fileURLWithPath: "/Applications", isDirectory: true)))
    #expect(roots.contains(home.appendingPathComponent("Applications", isDirectory: true)))
}

@Test("rekordbox matcher rejects unrelated applications")
func rejectsOtherApplicationsForRekordbox() {
    #expect(!RekordboxApplicationMatcher.matches(name: "Serato DJ Pro"))
    #expect(!RekordboxApplicationMatcher.matches(name: "djay Pro"))
    #expect(!RekordboxApplicationMatcher.matches(name: nil, bundleIdentifier: nil))
}
#endif
