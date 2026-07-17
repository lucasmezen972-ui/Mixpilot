#if os(macOS)
import Foundation
import MixPilotCore

public enum SeratoMappingInstallationState: Hashable, Sendable {
    case notInstalled
    case installed(version: String, directory: String)
    case updateAvailable(installedVersion: String?, expectedVersion: String)
    case damaged(String)
}

public struct SeratoMappingInstallationResult: Hashable, Sendable {
    public var presetPath: String
    public var autoSavePath: String
    public var backupPath: String?
    public var manifestPath: String
    public var supportedActionCount: Int
    public var unsupportedActions: [SeratoAction]
    public var fileInstallationStatus: String
    public var seratoValidationStatus: String

    public init(
        presetPath: String,
        autoSavePath: String,
        backupPath: String?,
        manifestPath: String,
        supportedActionCount: Int,
        unsupportedActions: [SeratoAction],
        fileInstallationStatus: String = "AUTOMATED_SUCCESS",
        seratoValidationStatus: String = "REQUIRES_SERATO_VALIDATION"
    ) {
        self.presetPath = presetPath
        self.autoSavePath = autoSavePath
        self.backupPath = backupPath
        self.manifestPath = manifestPath
        self.supportedActionCount = supportedActionCount
        self.unsupportedActions = unsupportedActions
        self.fileInstallationStatus = fileInstallationStatus
        self.seratoValidationStatus = seratoValidationStatus
    }
}

public struct SeratoMappingManifest: Codable, Hashable, Sendable {
    public var presetName: String
    public var presetVersion: String
    public var installedAt: Date
    public var supportedActions: [String]
    public var unsupportedActions: [String]
    public var generatedXMLBytes: Int
    public var sourceNotice: String

    public init(preset: SeratoXMLPreset, installedAt: Date) {
        presetName = preset.name
        presetVersion = preset.version
        self.installedAt = installedAt
        supportedActions = preset.supportedActions.map(\.rawValue).sorted()
        unsupportedActions = preset.unsupportedActions.map(\.rawValue).sorted()
        generatedXMLBytes = preset.xml.utf8.count
        sourceNotice = "MIT structure reference: marscanbueno/serato-dj-pro-midi-maps; command reference: Kovarsk/SERATO-XML-WIKI"
    }
}

public enum SeratoMappingInstallerError: Error, LocalizedError {
    case seratoMustBeClosed
    case invalidXML(String)
    case noBackupAvailable
    case installationVerificationFailed

    public var errorDescription: String? {
        switch self {
        case .seratoMustBeClosed:
            "Ferme complètement Serato DJ Pro avant d’installer le mapping."
        case .invalidXML(let reason):
            "Le preset XML généré est invalide : \(reason)"
        case .noBackupAvailable:
            "Aucune sauvegarde de mapping n’est disponible."
        case .installationVerificationFailed:
            "Les fichiers écrits ne correspondent pas au preset généré."
        }
    }
}

public final class SeratoMappingInstaller {
    public static let presetFilename = "MixPilot Autopilot.xml"
    public static let autoSaveFilename = "AUTO_SAVE.xml"
    public static let manifestFilename = "MixPilot Autopilot.manifest.json"

    private let fileManager: FileManager
    private let xmlDirectory: URL
    private let now: () -> Date

    public init(
        xmlDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.now = now
        self.xmlDirectory = xmlDirectory ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("_Serato_", isDirectory: true)
            .appendingPathComponent("MIDI", isDirectory: true)
            .appendingPathComponent("Xml", isDirectory: true)
    }

    public var installationDirectory: URL { xmlDirectory }

    public func inspect(expectedPreset: SeratoXMLPreset) -> SeratoMappingInstallationState {
        let presetURL = xmlDirectory.appendingPathComponent(Self.presetFilename)
        let autoSaveURL = xmlDirectory.appendingPathComponent(Self.autoSaveFilename)
        let manifestURL = xmlDirectory.appendingPathComponent(Self.manifestFilename)

        guard fileManager.fileExists(atPath: presetURL.path) ||
                fileManager.fileExists(atPath: autoSaveURL.path) ||
                fileManager.fileExists(atPath: manifestURL.path) else {
            return .notInstalled
        }

        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder.mixPilot.decode(SeratoMappingManifest.self, from: manifestData) else {
            return .damaged("Le manifeste MixPilot est absent ou illisible.")
        }

        guard manifest.presetVersion == expectedPreset.version else {
            return .updateAvailable(
                installedVersion: manifest.presetVersion,
                expectedVersion: expectedPreset.version
            )
        }

        guard let presetData = try? Data(contentsOf: presetURL),
              let autoSaveData = try? Data(contentsOf: autoSaveURL),
              presetData == Data(expectedPreset.xml.utf8),
              autoSaveData == Data(expectedPreset.xml.utf8) else {
            return .damaged("Le preset installé diffère de la version attendue.")
        }

        return .installed(version: manifest.presetVersion, directory: xmlDirectory.path)
    }

    @discardableResult
    public func install(
        preset: SeratoXMLPreset,
        seratoRunning: Bool
    ) throws -> SeratoMappingInstallationResult {
        guard !seratoRunning else { throw SeratoMappingInstallerError.seratoMustBeClosed }
        try validateXML(preset.xml)
        try fileManager.createDirectory(at: xmlDirectory, withIntermediateDirectories: true)

        let presetURL = xmlDirectory.appendingPathComponent(Self.presetFilename)
        let autoSaveURL = xmlDirectory.appendingPathComponent(Self.autoSaveFilename)
        let manifestURL = xmlDirectory.appendingPathComponent(Self.manifestFilename)
        let managedURLs = [presetURL, autoSaveURL, manifestURL]

        if case .installed = inspect(expectedPreset: preset) {
            return SeratoMappingInstallationResult(
                presetPath: presetURL.path,
                autoSavePath: autoSaveURL.path,
                backupPath: nil,
                manifestPath: manifestURL.path,
                supportedActionCount: preset.supportedActions.count,
                unsupportedActions: preset.unsupportedActions
            )
        }

        let backupURL = try createBackupIfNeeded(managedURLs: managedURLs)
        let xmlData = Data(preset.xml.utf8)
        try xmlData.write(to: presetURL, options: .atomic)
        try xmlData.write(to: autoSaveURL, options: .atomic)

        let manifest = SeratoMappingManifest(preset: preset, installedAt: now())
        let manifestData = try JSONEncoder.mixPilot.encode(manifest)
        try manifestData.write(to: manifestURL, options: .atomic)

        guard (try? Data(contentsOf: presetURL)) == xmlData,
              (try? Data(contentsOf: autoSaveURL)) == xmlData else {
            throw SeratoMappingInstallerError.installationVerificationFailed
        }
        try validateXML(String(decoding: Data(contentsOf: presetURL), as: UTF8.self))

        return SeratoMappingInstallationResult(
            presetPath: presetURL.path,
            autoSavePath: autoSaveURL.path,
            backupPath: backupURL?.path,
            manifestPath: manifestURL.path,
            supportedActionCount: preset.supportedActions.count,
            unsupportedActions: preset.unsupportedActions
        )
    }

    public func rollback(seratoRunning: Bool) throws -> String {
        guard !seratoRunning else { throw SeratoMappingInstallerError.seratoMustBeClosed }
        let backupRoot = xmlDirectory.appendingPathComponent("MixPilot Backups", isDirectory: true)
        let directories = (try? fileManager.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        guard let latest = directories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last else {
            throw SeratoMappingInstallerError.noBackupAvailable
        }

        let indexURL = latest.appendingPathComponent("backup-index.json")
        let indexData = try Data(contentsOf: indexURL)
        let index = try JSONDecoder.mixPilot.decode(SeratoMappingBackupIndex.self, from: indexData)

        for filename in index.managedFilenames {
            let destination = xmlDirectory.appendingPathComponent(filename)
            let source = latest.appendingPathComponent(filename)
            if index.existingFilenames.contains(filename) {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: source, to: destination)
            } else if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
        return latest.path
    }

    private func createBackupIfNeeded(managedURLs: [URL]) throws -> URL? {
        let existingURLs = managedURLs.filter { fileManager.fileExists(atPath: $0.path) }
        guard !existingURLs.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let backupURL = xmlDirectory
            .appendingPathComponent("MixPilot Backups", isDirectory: true)
            .appendingPathComponent(formatter.string(from: now()), isDirectory: true)
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

        for source in existingURLs {
            try fileManager.copyItem(
                at: source,
                to: backupURL.appendingPathComponent(source.lastPathComponent)
            )
        }

        let index = SeratoMappingBackupIndex(
            managedFilenames: managedURLs.map(\.lastPathComponent),
            existingFilenames: existingURLs.map(\.lastPathComponent)
        )
        try JSONEncoder.mixPilot.encode(index).write(
            to: backupURL.appendingPathComponent("backup-index.json"),
            options: .atomic
        )
        return backupURL
    }

    private func validateXML(_ xml: String) throws {
        let validator = SeratoXMLRootValidator()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.delegate = validator
        guard parser.parse(), validator.rootElement == "midi" else {
            throw SeratoMappingInstallerError.invalidXML(
                parser.parserError?.localizedDescription ?? "La racine <midi> est absente."
            )
        }
    }
}

private struct SeratoMappingBackupIndex: Codable {
    var managedFilenames: [String]
    var existingFilenames: [String]
}

private final class SeratoXMLRootValidator: NSObject, XMLParserDelegate {
    var rootElement: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if rootElement == nil { rootElement = elementName }
    }
}

private extension JSONEncoder {
    static var mixPilot: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var mixPilot: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
#endif
