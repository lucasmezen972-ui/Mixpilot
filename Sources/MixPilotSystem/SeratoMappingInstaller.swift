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
    case invalidBackup(String)
    case installationVerificationFailed
    case automaticRecoveryFailed(operation: String, recovery: String)

    public var errorDescription: String? {
        switch self {
        case .seratoMustBeClosed:
            "Ferme complètement Serato DJ Pro avant d’installer le mapping."
        case .invalidXML(let reason):
            "Le preset XML généré est invalide : \(reason)"
        case .noBackupAvailable:
            "Aucune sauvegarde de mapping n’est disponible."
        case .invalidBackup(let reason):
            "La sauvegarde Serato ne peut pas être restaurée : \(reason)"
        case .installationVerificationFailed:
            "Les fichiers écrits ne correspondent pas au preset généré."
        case .automaticRecoveryFailed(let operation, let recovery):
            "L’opération Serato a échoué (\(operation)) et la restauration automatique est incomplète (\(recovery))."
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
        let urls = managedURLs
        guard urls.contains(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return .notInstalled
        }

        do {
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder.mixPilot.decode(
                SeratoMappingManifest.self,
                from: manifestData
            )
            guard manifest.presetVersion == expectedPreset.version else {
                return .updateAvailable(
                    installedVersion: manifest.presetVersion,
                    expectedVersion: expectedPreset.version
                )
            }

            let expectedXML = Data(expectedPreset.xml.utf8)
            let presetData = try Data(contentsOf: presetURL)
            let autoSaveData = try Data(contentsOf: autoSaveURL)
            guard presetData == expectedXML, autoSaveData == expectedXML else {
                return .damaged("Le preset installé diffère de la version attendue.")
            }
            return .installed(version: manifest.presetVersion, directory: xmlDirectory.path)
        } catch {
            return .damaged("Le manifeste ou les fichiers MixPilot sont illisibles : \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func install(
        preset: SeratoXMLPreset,
        seratoRunning: Bool
    ) throws -> SeratoMappingInstallationResult {
        guard !seratoRunning else { throw SeratoMappingInstallerError.seratoMustBeClosed }
        try validateXML(preset.xml)
        try fileManager.createDirectory(at: xmlDirectory, withIntermediateDirectories: true)

        if case .installed = inspect(expectedPreset: preset) {
            return installationResult(preset: preset, backupURL: nil)
        }

        let snapshot = try captureSnapshot(urls: managedURLs)
        let backupURL = try createBackupIfNeeded(managedURLs: managedURLs)
        let xmlData = Data(preset.xml.utf8)
        let manifest = SeratoMappingManifest(preset: preset, installedAt: now())
        let manifestData = try JSONEncoder.mixPilot.encode(manifest)

        do {
            try xmlData.write(to: presetURL, options: .atomic)
            try xmlData.write(to: autoSaveURL, options: .atomic)
            try manifestData.write(to: manifestURL, options: .atomic)
            try verifyInstallation(
                expectedXML: xmlData,
                expectedManifest: manifest,
                expectedManifestData: manifestData
            )
            return installationResult(preset: preset, backupURL: backupURL)
        } catch let operationError {
            do {
                try restore(snapshot: snapshot)
            } catch let recoveryError {
                throw SeratoMappingInstallerError.automaticRecoveryFailed(
                    operation: operationError.localizedDescription,
                    recovery: recoveryError.localizedDescription
                )
            }
            throw operationError
        }
    }

    public func rollback(seratoRunning: Bool) throws -> String {
        guard !seratoRunning else { throw SeratoMappingInstallerError.seratoMustBeClosed }
        let backupRoot = xmlDirectory.appendingPathComponent("MixPilot Backups", isDirectory: true)
        guard fileManager.fileExists(atPath: backupRoot.path) else {
            throw SeratoMappingInstallerError.noBackupAvailable
        }

        let directories = try fileManager.contentsOfDirectory(
            at: backupRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        guard let latest = directories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).last else {
            throw SeratoMappingInstallerError.noBackupAvailable
        }

        let indexURL = latest.appendingPathComponent("backup-index.json")
        let indexData = try Data(contentsOf: indexURL)
        let index = try JSONDecoder.mixPilot.decode(SeratoMappingBackupIndex.self, from: indexData)
        try validateBackupIndex(index)

        var restoredData: [String: Data] = [:]
        for filename in index.existingFilenames {
            restoredData[filename] = try Data(contentsOf: latest.appendingPathComponent(filename))
        }

        let snapshot = try captureSnapshot(urls: managedURLs)
        do {
            for filename in index.managedFilenames {
                let destination = xmlDirectory.appendingPathComponent(filename)
                if let data = restoredData[filename] {
                    try data.write(to: destination, options: .atomic)
                } else if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
            }
            try verifyRollback(index: index, restoredData: restoredData)
            return latest.path
        } catch let operationError {
            do {
                try restore(snapshot: snapshot)
            } catch let recoveryError {
                throw SeratoMappingInstallerError.automaticRecoveryFailed(
                    operation: operationError.localizedDescription,
                    recovery: recoveryError.localizedDescription
                )
            }
            throw operationError
        }
    }

    private var presetURL: URL {
        xmlDirectory.appendingPathComponent(Self.presetFilename)
    }

    private var autoSaveURL: URL {
        xmlDirectory.appendingPathComponent(Self.autoSaveFilename)
    }

    private var manifestURL: URL {
        xmlDirectory.appendingPathComponent(Self.manifestFilename)
    }

    private var managedURLs: [URL] {
        [presetURL, autoSaveURL, manifestURL]
    }

    private var allowedManagedFilenames: Set<String> {
        Set(managedURLs.map(\.lastPathComponent))
    }

    private func installationResult(
        preset: SeratoXMLPreset,
        backupURL: URL?
    ) -> SeratoMappingInstallationResult {
        SeratoMappingInstallationResult(
            presetPath: presetURL.path,
            autoSavePath: autoSaveURL.path,
            backupPath: backupURL?.path,
            manifestPath: manifestURL.path,
            supportedActionCount: preset.supportedActions.count,
            unsupportedActions: preset.unsupportedActions
        )
    }

    private func verifyInstallation(
        expectedXML: Data,
        expectedManifest: SeratoMappingManifest,
        expectedManifestData: Data
    ) throws {
        guard try Data(contentsOf: presetURL) == expectedXML,
              try Data(contentsOf: autoSaveURL) == expectedXML,
              try Data(contentsOf: manifestURL) == expectedManifestData else {
            throw SeratoMappingInstallerError.installationVerificationFailed
        }
        try validateXML(String(decoding: expectedXML, as: UTF8.self))
        let decodedManifest = try JSONDecoder.mixPilot.decode(
            SeratoMappingManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        guard decodedManifest == expectedManifest else {
            throw SeratoMappingInstallerError.installationVerificationFailed
        }
    }

    private func verifyRollback(
        index: SeratoMappingBackupIndex,
        restoredData: [String: Data]
    ) throws {
        for filename in index.managedFilenames {
            let destination = xmlDirectory.appendingPathComponent(filename)
            if let expected = restoredData[filename] {
                guard try Data(contentsOf: destination) == expected else {
                    throw SeratoMappingInstallerError.installationVerificationFailed
                }
            } else if fileManager.fileExists(atPath: destination.path) {
                throw SeratoMappingInstallerError.installationVerificationFailed
            }
        }
    }

    private func captureSnapshot(urls: [URL]) throws -> [String: Data?] {
        var snapshot: [String: Data?] = [:]
        for url in urls {
            snapshot[url.lastPathComponent] = fileManager.fileExists(atPath: url.path)
                ? try Data(contentsOf: url)
                : nil
        }
        return snapshot
    }

    private func restore(snapshot: [String: Data?]) throws {
        for (filename, data) in snapshot {
            let destination = xmlDirectory.appendingPathComponent(filename)
            if let data {
                try data.write(to: destination, options: .atomic)
            } else if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
        }
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

    private func validateBackupIndex(_ index: SeratoMappingBackupIndex) throws {
        let managed = Set(index.managedFilenames)
        let existing = Set(index.existingFilenames)
        guard !managed.isEmpty,
              managed.isSubset(of: allowedManagedFilenames),
              existing.isSubset(of: managed),
              index.managedFilenames.allSatisfy(isSafeFilename),
              index.existingFilenames.allSatisfy(isSafeFilename) else {
            throw SeratoMappingInstallerError.invalidBackup(
                "le manifeste de sauvegarde contient des chemins ou fichiers non autorisés"
            )
        }
    }

    private func isSafeFilename(_ filename: String) -> Bool {
        guard !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              !filename.contains("/"),
              !filename.contains("\\") else {
            return false
        }
        return true
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
