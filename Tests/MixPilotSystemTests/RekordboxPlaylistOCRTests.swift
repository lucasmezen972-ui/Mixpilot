#if os(macOS)
import CoreGraphics
import Testing
@testable import MixPilotSystem

@Test("rekordbox OCR rows pair visible titles and artists")
func rekordboxOCRRowsPairVisibleColumns() {
    let fragments = [
        RekordboxOCRFragment(text: "Titre du morceau", bounds: CGRect(x: 0.46, y: 0.32, width: 0.08, height: 0.02)),
        RekordboxOCRFragment(text: "Artiste", bounds: CGRect(x: 0.55, y: 0.32, width: 0.04, height: 0.02)),
        RekordboxOCRFragment(text: "Le Mix shatta de PAPA", bounds: CGRect(x: 0.46, y: 0.30, width: 0.08, height: 0.02)),
        RekordboxOCRFragment(text: "Bermixx", bounds: CGRect(x: 0.55, y: 0.30, width: 0.04, height: 0.02)),
        RekordboxOCRFragment(text: "YENKI ÈVEW", bounds: CGRect(x: 0.46, y: 0.28, width: 0.07, height: 0.02)),
        RekordboxOCRFragment(text: "Misié", bounds: CGRect(x: 0.55, y: 0.28, width: 0.03, height: 0.02)),
        RekordboxOCRFragment(text: "Playlist latérale", bounds: CGRect(x: 0.08, y: 0.28, width: 0.08, height: 0.02)),
    ]

    let rows = RekordboxPlaylistOCRParser().rows(from: fragments, maxRows: 100)

    #expect(rows.map(\.fields) == [
        ["Le Mix shatta de PAPA", "Bermixx"],
        ["YENKI ÈVEW", "Misié"],
    ])
}
#endif
