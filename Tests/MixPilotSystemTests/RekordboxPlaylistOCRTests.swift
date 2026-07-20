#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@testable import MixPilotSystem

@Test("rekordbox OCR rows pair French visible titles and artists")
func rekordboxOCRRowsPairFrenchVisibleColumns() {
    let rows = parsedRows(titleHeader: "Titre du morceau", artistHeader: "Artiste")

    #expect(rows.map(\.fields) == [
        ["Le Mix shatta de PAPA", "Bermixx"],
        ["YENKI ÈVEW", "Misié"],
    ])
}

@Test("rekordbox OCR rows pair English visible titles and artists")
func rekordboxOCRRowsPairEnglishVisibleColumns() {
    let rows = parsedRows(titleHeader: "Track Title", artistHeader: "Artist")

    #expect(rows.map(\.fields) == [
        ["Le Mix shatta de PAPA", "Bermixx"],
        ["YENKI ÈVEW", "Misié"],
    ])
}

@Test("rekordbox OCR rows pair Spanish visible titles and artists")
func rekordboxOCRRowsPairSpanishVisibleColumns() {
    let rows = parsedRows(titleHeader: "Título", artistHeader: "Artista")

    #expect(rows.map(\.fields) == [
        ["Le Mix shatta de PAPA", "Bermixx"],
        ["YENKI ÈVEW", "Misié"],
    ])
}

@Test("rekordbox OCR uses geometry when headers are unavailable")
func rekordboxOCRUsesGeometryWithoutHeaders() {
    let fragments = [
        RekordboxOCRFragment(text: "Le Mix shatta de PAPA", bounds: CGRect(x: 0.42, y: 0.30, width: 0.12, height: 0.02)),
        RekordboxOCRFragment(text: "Bermixx", bounds: CGRect(x: 0.62, y: 0.30, width: 0.06, height: 0.02)),
        RekordboxOCRFragment(text: "YENKI ÈVEW", bounds: CGRect(x: 0.42, y: 0.27, width: 0.09, height: 0.02)),
        RekordboxOCRFragment(text: "Misié", bounds: CGRect(x: 0.62, y: 0.27, width: 0.05, height: 0.02)),
        RekordboxOCRFragment(text: "Playlist latérale", bounds: CGRect(x: 0.08, y: 0.27, width: 0.10, height: 0.02)),
    ]

    let result = RekordboxPlaylistOCRParser().parse(fragments: fragments, maxRows: 100)

    #expect(result.usedGeometricFallback)
    #expect(result.confidence < 0.8)
    #expect(result.rows.map(\.fields) == [
        ["Le Mix shatta de PAPA", "Bermixx"],
        ["YENKI ÈVEW", "Misié"],
    ])
}

@Test("cached Rekordbox OCR is explicitly not a current observation")
func cachedRekordboxOCRIsNotCurrent() {
    let generatedAt = Date(timeIntervalSince1970: 1_000)
    let observation = RekordboxLibraryObservation(
        rows: [DJLibraryRow(index: 0, fields: ["Titre", "Artiste"])],
        source: .cachedOCR(observedAt: generatedAt),
        collectedAt: generatedAt.addingTimeInterval(90),
        confidence: 0.75
    )

    #expect(!observation.isCurrent)
    #expect(observation.cacheAge == 90)
}

@Test("fresh Rekordbox OCR is a current observation")
func freshRekordboxOCRIsCurrent() {
    let observedAt = Date(timeIntervalSince1970: 2_000)
    let observation = RekordboxLibraryObservation(
        rows: [DJLibraryRow(index: 0, fields: ["Titre", "Artiste"])],
        source: .freshOCR(observedAt: observedAt),
        collectedAt: observedAt,
        confidence: 0.9
    )

    #expect(observation.isCurrent)
    #expect(observation.cacheAge == nil)
}

private func parsedRows(titleHeader: String, artistHeader: String) -> [DJLibraryRow] {
    let fragments = [
        RekordboxOCRFragment(text: titleHeader, bounds: CGRect(x: 0.46, y: 0.32, width: 0.08, height: 0.02)),
        RekordboxOCRFragment(text: artistHeader, bounds: CGRect(x: 0.55, y: 0.32, width: 0.05, height: 0.02)),
        RekordboxOCRFragment(text: "Le Mix shatta de PAPA", bounds: CGRect(x: 0.46, y: 0.30, width: 0.08, height: 0.02)),
        RekordboxOCRFragment(text: "Bermixx", bounds: CGRect(x: 0.55, y: 0.30, width: 0.04, height: 0.02)),
        RekordboxOCRFragment(text: "YENKI ÈVEW", bounds: CGRect(x: 0.46, y: 0.28, width: 0.07, height: 0.02)),
        RekordboxOCRFragment(text: "Misié", bounds: CGRect(x: 0.55, y: 0.28, width: 0.03, height: 0.02)),
        RekordboxOCRFragment(text: "Playlist latérale", bounds: CGRect(x: 0.08, y: 0.28, width: 0.08, height: 0.02)),
    ]

    return RekordboxPlaylistOCRParser().rows(from: fragments, maxRows: 100)
}
#endif
