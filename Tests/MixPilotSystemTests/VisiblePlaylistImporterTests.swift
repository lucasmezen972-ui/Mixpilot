#if os(macOS)
import Testing
@testable import MixPilotCore
@testable import MixPilotSystem

@Test("Visible playlist rows are imported without backend-specific types")
func visibleRowsImportGenericTracks() {
    let rows = [
        DJLibraryRow(index: 0, fields: ["Water", "Tyla", "123", "3:20", "8A"]),
        DJLibraryRow(index: 1, fields: ["Water", "Tyla", "123", "3:20", "8A"]),
        DJLibraryRow(index: 2, fields: ["Shatta Energy", "Maureen", "105,5", "2:45"]),
    ]

    let result = VisiblePlaylistImporter().importRows(rows)

    #expect(result.sourceRowCount == 3)
    #expect(result.tracks.count == 2)
    #expect(result.tracks[0].title == "Water")
    #expect(result.tracks[0].artist == "Tyla")
    #expect(result.tracks[0].bpm == 123)
    #expect(result.tracks[0].duration == 200)
    #expect(result.tracks[0].profile == .amapiano)
    #expect(result.tracks[1].profile == .shatta)
    #expect(result.warnings.isEmpty)
}

@Test("Missing visible metadata uses explicit provisional values")
func visibleRowsReportProvisionalMetadata() {
    let rows = [DJLibraryRow(index: 7, fields: ["Unknown Song", "Unknown Artist"])]

    let result = VisiblePlaylistImporter().importRows(rows, defaultProfile: .safe)

    #expect(result.tracks.count == 1)
    #expect(result.tracks[0].bpm == 100)
    #expect(result.tracks[0].duration == 210)
    #expect(result.tracks[0].profile == .safe)
    #expect(result.warnings.count == 2)
    #expect(result.warnings.allSatisfy { $0.rowIndex == 7 })
    #expect(result.warnings.contains { $0.message.contains("BPM") })
    #expect(result.warnings.contains { $0.message.contains("Durée") })
}

@Test("Rows without a usable title are ignored safely")
func visibleRowsWithoutTitleAreRejected() {
    let rows = [DJLibraryRow(index: 3, fields: ["128", "4:00", "9A"])]

    let result = VisiblePlaylistImporter().importRows(rows)

    #expect(result.tracks.isEmpty)
    #expect(result.warnings.count == 1)
    #expect(result.warnings[0].rowIndex == 3)
    #expect(result.warnings[0].message.contains("Titre"))
}
#endif
