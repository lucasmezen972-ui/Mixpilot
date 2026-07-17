import XCTest
@testable import MixPilotCore

final class RekordboxMIDIPresetTests: XCTestCase {
    func testGeneratorBuildsImportableRekordboxCSV() throws {
        let preset = try RekordboxMIDIPresetGenerator().generate(
            profile: .developmentDefault,
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(preset.csv.hasPrefix("@file,1,MixPilot Virtual Controller\n"))
        XCTAssertTrue(preset.supportedActions.contains(.playA))
        XCTAssertTrue(preset.supportedActions.contains(.loadB))
        XCTAssertTrue(preset.unsupportedActions.contains(.browserFocus))
        XCTAssertTrue(preset.unsupportedActions.contains(.filterA))
        XCTAssertEqual(preset.validationStatus, .requiresDeviceValidation)
        XCTAssertNoThrow(try RekordboxMIDIPresetValidator().validate(csv: preset.csv))
    }

    func testDeckAndGlobalColumnsMatchRekordboxFormat() throws {
        let preset = try RekordboxMIDIPresetGenerator().generate(profile: .developmentDefault)
        let rows = preset.csv.split(whereSeparator: \.isNewline).dropFirst().map(String.init)

        let playA = try XCTUnwrap(rows.first { $0.hasPrefix("PlayPause,playA,") })
        let playAColumns = splitCSV(playA)
        XCTAssertEqual(playAColumns.count, 15)
        XCTAssertEqual(playAColumns[2], "Button")
        XCTAssertEqual(playAColumns[3], "")
        XCTAssertEqual(playAColumns[4], "903C")
        XCTAssertEqual(playAColumns[5], "")

        let playB = try XCTUnwrap(rows.first { $0.hasPrefix("PlayPause,playB,") })
        let playBColumns = splitCSV(playB)
        XCTAssertEqual(playBColumns[4], "")
        XCTAssertEqual(playBColumns[5], "903D")

        let crossfader = try XCTUnwrap(rows.first { $0.hasPrefix("CrossFader,crossfader,") })
        let crossfaderColumns = splitCSV(crossfader)
        XCTAssertEqual(crossfaderColumns[2], "KnobSlider")
        XCTAssertEqual(crossfaderColumns[3], "B00A")
        XCTAssertEqual(crossfaderColumns[4], "")
        XCTAssertEqual(crossfaderColumns[5], "")
    }

    func testMIDIHexUsesMessageKindAndChannel() {
        XCTAssertEqual(
            RekordboxMIDIPresetGenerator.midiHex(
                for: MIDIMessageMapping(kind: .note, channel: 2, number: 64)
            ),
            "9240"
        )
        XCTAssertEqual(
            RekordboxMIDIPresetGenerator.midiHex(
                for: MIDIMessageMapping(kind: .controlChange, channel: 15, number: 10)
            ),
            "BF0A"
        )
    }

    func testValidatorRejectsDuplicateMIDICodes() {
        let csv = """
        @file,1,MixPilot Virtual Controller
        PlayPause,playA,Button,,903C,,,,,,,,,Fast;,MixPilot playA
        Cue,cueA,Button,,903C,,,,,,,,,Fast;,MixPilot cueA
        """

        XCTAssertThrowsError(try RekordboxMIDIPresetValidator().validate(csv: csv)) { error in
            XCTAssertEqual(error as? RekordboxMIDIPresetError, .duplicateMIDIHex("903C"))
        }
    }

    func testValidatorRejectsUnknownCommand() {
        let csv = """
        @file,1,MixPilot Virtual Controller
        InventedCommand,playA,Button,,903C,,,,,,,,,Fast;,bad
        """

        XCTAssertThrowsError(try RekordboxMIDIPresetValidator().validate(csv: csv)) { error in
            XCTAssertEqual(
                error as? RekordboxMIDIPresetError,
                .unknownCommand(line: 2, command: "InventedCommand")
            )
        }
    }

    func testRegistryDoesNotInventUnverifiedFXOrBrowserFocus() {
        XCTAssertNil(RekordboxMIDICommandRegistry.definition(for: .browserFocus))
        XCTAssertNil(RekordboxMIDICommandRegistry.definition(for: .filterA))
        XCTAssertNil(RekordboxMIDICommandRegistry.definition(for: .echoA))
        XCTAssertEqual(RekordboxMIDICommandRegistry.definition(for: .loopA)?.csvName, "BeatLoop4")
        XCTAssertEqual(RekordboxMIDICommandRegistry.definition(for: .exitLoopA)?.csvName, "ReloopExit")
    }

    private func splitCSV(_ line: String) -> [String] {
        line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    }
}
