#if os(macOS)
import Foundation
import Testing
@testable import MixPilotCore
@testable import MixPilotSystem

@Test("Automatic Serato mapping installs both named preset and AUTO_SAVE")
func automaticMappingInstall() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let installer = SeratoMappingInstaller(xmlDirectory: directory)
    let preset = SeratoXMLPresetGenerator().generate(profile: .developmentDefault)
    let result = try installer.install(preset: preset, seratoRunning: false)

    #expect(FileManager.default.fileExists(atPath: result.presetPath))
    #expect(FileManager.default.fileExists(atPath: result.autoSavePath))
    #expect(FileManager.default.fileExists(atPath: result.manifestPath))
    #expect(result.backupPath == nil)
    #expect(result.fileInstallationStatus == "AUTOMATED_SUCCESS")
    #expect(result.seratoValidationStatus == "REQUIRES_SERATO_VALIDATION")
    #expect(try String(contentsOfFile: result.presetPath, encoding: .utf8) == preset.xml)
    #expect(try String(contentsOfFile: result.autoSavePath, encoding: .utf8) == preset.xml)

    guard case .installed(let version, let installedDirectory) = installer.inspect(expectedPreset: preset) else {
        Issue.record("Expected installed state")
        return
    }
    #expect(version == preset.version)
    #expect(installedDirectory == directory.path)
}

@Test("Existing Serato AUTO_SAVE is backed up and restored")
func existingMappingBackupAndRollback() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let original = "<midi app=\"Original\"></midi>"
    let autoSave = directory.appendingPathComponent(SeratoMappingInstaller.autoSaveFilename)
    try original.write(to: autoSave, atomically: true, encoding: .utf8)

    let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    let installer = SeratoMappingInstaller(
        xmlDirectory: directory,
        now: { fixedDate }
    )
    let preset = SeratoXMLPresetGenerator().generate(profile: .developmentDefault)
    let result = try installer.install(preset: preset, seratoRunning: false)

    #expect(result.backupPath != nil)
    #expect(try String(contentsOf: autoSave, encoding: .utf8) == preset.xml)

    let restoredBackup = try installer.rollback(seratoRunning: false)
    #expect(restoredBackup == result.backupPath)
    #expect(try String(contentsOf: autoSave, encoding: .utf8) == original)
    #expect(!FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(SeratoMappingInstaller.presetFilename).path
    ))
    #expect(!FileManager.default.fileExists(
        atPath: directory.appendingPathComponent(SeratoMappingInstaller.manifestFilename).path
    ))
}

@Test("Installer refuses to write while Serato is running")
func installerRefusesRunningSerato() {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let installer = SeratoMappingInstaller(xmlDirectory: directory)
    let preset = SeratoXMLPresetGenerator().generate(profile: .developmentDefault)

    #expect(throws: SeratoMappingInstallerError.self) {
        try installer.install(preset: preset, seratoRunning: true)
    }
    #expect(!FileManager.default.fileExists(atPath: directory.path))
}

@Test("Reinstalling the identical preset is idempotent")
func identicalReinstallIsIdempotent() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }

    let installer = SeratoMappingInstaller(xmlDirectory: directory)
    let preset = SeratoXMLPresetGenerator().generate(profile: .developmentDefault)
    _ = try installer.install(preset: preset, seratoRunning: false)
    let second = try installer.install(preset: preset, seratoRunning: false)

    #expect(second.backupPath == nil)
    #expect(second.supportedActionCount == preset.supportedActions.count)
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("MixPilotSeratoMappingTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}
#endif
