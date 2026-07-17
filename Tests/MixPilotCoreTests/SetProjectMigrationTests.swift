import Foundation
import Testing
@testable import MixPilotCore

private func migrationProject(backend: DJBackendIdentifier? = nil) -> SetProject {
    let tracks = [
        Track(
            title: "A",
            artist: "Artist A",
            bpm: 120,
            duration: 180,
            energy: 0.5,
            vocalDensity: 0.2,
            profile: .afro
        ),
        Track(
            title: "B",
            artist: "Artist B",
            bpm: 121,
            duration: 182,
            energy: 0.6,
            vocalDensity: 0.3,
            profile: .afro
        )
    ]
    return SetPreparationEngine().prepare(
        name: "Migration",
        tracks: tracks,
        backend: backend
    )
}

@Test("A legacy set without backend remains unassigned")
func legacySetDoesNotInventSerato() throws {
    let current = migrationProject(backend: .rekordbox)
    let encoded = try JSONEncoder().encode(current)
    var object = try #require(
        JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    )
    object.removeValue(forKey: "backend")
    object.removeValue(forKey: "formatVersion")

    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let decoded = try JSONDecoder().decode(SetProject.self, from: legacyData)

    #expect(decoded.formatVersion == SetProject.currentFormatVersion)
    #expect(decoded.backend == nil)
    #expect(decoded.requiresBackendSelection)
    #expect(decoded.name == current.name)
    #expect(decoded.tracks.count == current.tracks.count)
}

@Test("A new set persists its explicit backend")
func newSetPersistsBackend() throws {
    let project = migrationProject(backend: .djay)
    let data = try JSONEncoder().encode(project)
    let decoded = try JSONDecoder().decode(SetProject.self, from: data)

    #expect(decoded.formatVersion == SetProject.currentFormatVersion)
    #expect(decoded.backend == .djay)
    #expect(!decoded.requiresBackendSelection)
}

@Test("Changing backend updates the project without changing the set plan")
func changingBackendPreservesPreparedPlan() {
    var project = migrationProject(backend: .serato)
    let trackIDs = project.tracks.map(\.id)
    let transitionIDs = project.transitions.map(\.id)

    project.selectBackend(.rekordbox)

    #expect(project.backend == .rekordbox)
    #expect(project.tracks.map(\.id) == trackIDs)
    #expect(project.transitions.map(\.id) == transitionIDs)
}
