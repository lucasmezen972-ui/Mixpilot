import Foundation

public enum RekordboxDeviceValidationOutcome: String, Codable, CaseIterable, Sendable {
    case untested
    case passed
    case failed
    case skipped

    public var displayName: String {
        switch self {
        case .untested: "À tester"
        case .passed: "Validée"
        case .failed: "Échec"
        case .skipped: "Ignorée"
        }
    }
}

public struct RekordboxDeviceValidationTarget: Codable, Hashable, Sendable {
    public var rekordboxVersion: String
    public var controllerName: String
    public var presetSignature: String

    public init(rekordboxVersion: String?, controllerName: String, presetCSV: String) {
        self.rekordboxVersion = Self.normalizedVersion(rekordboxVersion)
        self.controllerName = controllerName
        self.presetSignature = Self.signature(
            version: self.rekordboxVersion,
            controllerName: controllerName,
            csv: presetCSV
        )
    }

    public var identifier: String {
        "rekordbox-\(rekordboxVersion)-\(presetSignature)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    private static func normalizedVersion(_ value: String?) -> String {
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return cleaned.isEmpty ? "unknown" : cleaned
    }

    private static func signature(version: String, controllerName: String, csv: String) -> String {
        let bytes = Array("\(version)\u{1F}\(controllerName)\u{1F}\(csv)".utf8)
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llX", hash)
    }
}

public struct RekordboxDeviceValidationCommand: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var action: SeratoAction
    public var csvName: String
    public var title: String
    public var category: String
    public var controlType: RekordboxMIDIControlType
    public var scope: RekordboxMIDIScope
    public var midiHex: String
    public var minimumVersion: String?
    public var warning: String?
    public var isCritical: Bool
    public var isAvailableForInstalledVersion: Bool

    public init(
        action: SeratoAction,
        csvName: String,
        title: String,
        category: String,
        controlType: RekordboxMIDIControlType,
        scope: RekordboxMIDIScope,
        midiHex: String,
        minimumVersion: String? = nil,
        warning: String? = nil,
        isCritical: Bool,
        isAvailableForInstalledVersion: Bool
    ) {
        self.id = "\(action.rawValue):\(csvName)"
        self.action = action
        self.csvName = csvName
        self.title = title
        self.category = category
        self.controlType = controlType
        self.scope = scope
        self.midiHex = midiHex
        self.minimumVersion = minimumVersion
        self.warning = warning
        self.isCritical = isCritical
        self.isAvailableForInstalledVersion = isAvailableForInstalledVersion
    }
}

public struct RekordboxDeviceValidationPlan: Codable, Hashable, Sendable {
    public var target: RekordboxDeviceValidationTarget
    public var commands: [RekordboxDeviceValidationCommand]
    public var generatedAt: Date

    public init(
        target: RekordboxDeviceValidationTarget,
        commands: [RekordboxDeviceValidationCommand],
        generatedAt: Date = Date()
    ) {
        self.target = target
        self.commands = commands
        self.generatedAt = generatedAt
    }

    public var criticalCommandCount: Int { commands.filter(\.isCritical).count }
}

public struct RekordboxDeviceValidationRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String { commandID }
    public var commandID: String
    public var outcome: RekordboxDeviceValidationOutcome
    public var testedAt: Date?
    public var note: String?

    public init(
        commandID: String,
        outcome: RekordboxDeviceValidationOutcome = .untested,
        testedAt: Date? = nil,
        note: String? = nil
    ) {
        self.commandID = commandID
        self.outcome = outcome
        self.testedAt = testedAt
        self.note = note
    }
}

public struct RekordboxDeviceValidationReport: Codable, Hashable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var target: RekordboxDeviceValidationTarget
    public var records: [String: RekordboxDeviceValidationRecord]
    public var createdAt: Date
    public var updatedAt: Date

    public init(plan: RekordboxDeviceValidationPlan, date: Date = Date()) {
        self.schemaVersion = Self.schemaVersion
        self.target = plan.target
        self.records = plan.commands.reduce(into: [:]) { records, command in
            records[command.id] = RekordboxDeviceValidationRecord(commandID: command.id)
        }
        self.createdAt = date
        self.updatedAt = date
    }

    public subscript(commandID: String) -> RekordboxDeviceValidationRecord {
        records[commandID] ?? RekordboxDeviceValidationRecord(commandID: commandID)
    }

    public mutating func record(
        _ outcome: RekordboxDeviceValidationOutcome,
        for commandID: String,
        note: String? = nil,
        date: Date = Date()
    ) {
        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        records[commandID] = RekordboxDeviceValidationRecord(
            commandID: commandID,
            outcome: outcome,
            testedAt: outcome == .untested ? nil : date,
            note: cleanedNote?.isEmpty == false ? cleanedNote : nil
        )
        updatedAt = date
    }

    public mutating func synchronize(with plan: RekordboxDeviceValidationPlan, date: Date = Date()) {
        guard target == plan.target else {
            self = RekordboxDeviceValidationReport(plan: plan, date: date)
            return
        }
        let validIDs = Set(plan.commands.map(\.id))
        records = records.filter { validIDs.contains($0.key) }
        for command in plan.commands where records[command.id] == nil {
            records[command.id] = RekordboxDeviceValidationRecord(commandID: command.id)
        }
        updatedAt = date
    }

    public func outcome(for command: RekordboxDeviceValidationCommand) -> RekordboxDeviceValidationOutcome {
        self[command.id].outcome
    }

    public var testedCount: Int {
        records.values.filter { $0.outcome != .untested }.count
    }

    public var passedCount: Int {
        records.values.filter { $0.outcome == .passed }.count
    }

    public func completionRatio(for plan: RekordboxDeviceValidationPlan) -> Double {
        let available = plan.commands.filter(\.isAvailableForInstalledVersion)
        guard !available.isEmpty else { return 0 }
        let completed = available.filter { self[$0.id].outcome != .untested }.count
        return Double(completed) / Double(available.count)
    }

    public func passedRatio(for plan: RekordboxDeviceValidationPlan) -> Double {
        let available = plan.commands.filter(\.isAvailableForInstalledVersion)
        guard !available.isEmpty else { return 0 }
        let passed = available.filter { self[$0.id].outcome == .passed }.count
        return Double(passed) / Double(available.count)
    }

    public func criticalCommandsPassed(in plan: RekordboxDeviceValidationPlan) -> Bool {
        let critical = plan.commands.filter { $0.isCritical && $0.isAvailableForInstalledVersion }
        return !critical.isEmpty && critical.allSatisfy { self[$0.id].outcome == .passed }
    }
}

public struct RekordboxDeviceValidationPlanBuilder: Sendable {
    public init() {}

    public func make(
        profile: MIDIMappingProfile,
        installedVersion: String?,
        generatedAt: Date = Date()
    ) throws -> RekordboxDeviceValidationPlan {
        let preset = try RekordboxAdvancedMIDIPresetGenerator().generate(
            profile: profile,
            generatedAt: generatedAt
        )
        let target = RekordboxDeviceValidationTarget(
            rekordboxVersion: installedVersion,
            controllerName: preset.base.controllerName,
            presetCSV: preset.csv
        )
        let actions = orderedUnique(preset.base.supportedActions + preset.addedActions)
        let installed = installedVersion.flatMap(RekordboxSemanticVersion.init)
        let commands = actions.compactMap { action -> RekordboxDeviceValidationCommand? in
            guard let mapping = profile[action], let definition = definition(for: action) else { return nil }
            let catalogue = RekordboxExtendedCommandCatalog.commands.first { $0.csvName == definition.csvName }
            let minimum = minimumVersion(for: action)
            let available = isAvailable(installed: installed, minimumVersion: minimum)
            return RekordboxDeviceValidationCommand(
                action: action,
                csvName: definition.csvName,
                title: catalogue?.title ?? action.rawValue,
                category: catalogue?.category ?? "Commande",
                controlType: definition.controlType,
                scope: definition.scope,
                midiHex: RekordboxMIDIPresetGenerator.midiHex(for: mapping),
                minimumVersion: minimum,
                warning: definition.semanticWarning ?? catalogue?.warning,
                isCritical: SeratoAction.automaticPresetCriticalActions.contains(action),
                isAvailableForInstalledVersion: available
            )
        }
        return RekordboxDeviceValidationPlan(target: target, commands: commands, generatedAt: generatedAt)
    }

    private func orderedUnique(_ actions: [SeratoAction]) -> [SeratoAction] {
        var seen = Set<SeratoAction>()
        return actions.filter { seen.insert($0).inserted }
    }

    private func definition(for action: SeratoAction) -> RekordboxMIDICommandDefinition? {
        if let base = RekordboxMIDICommandRegistry.definition(for: action) { return base }
        switch action {
        case .browserFocus:
            return RekordboxMIDICommandDefinition(
                csvName: "SwitchActiveWindow",
                controlType: .button,
                scope: .global,
                sourceVersions: ["6.6.3", "6.7.4"],
                semanticWarning: "Confirme que la commande ouvre la fenêtre Bibliothèque utilisée en Live."
            )
        case .filterA:
            return RekordboxMIDICommandDefinition(
                csvName: "CFXParameterCH1",
                controlType: .knobSlider,
                scope: .global,
                sourceVersions: ["6.7.4"],
                semanticWarning: "Sélectionne Filter comme Color FX sur le canal 1 avant le test."
            )
        case .filterB:
            return RekordboxMIDICommandDefinition(
                csvName: "CFXParameterCH2",
                controlType: .knobSlider,
                scope: .global,
                sourceVersions: ["6.7.4"],
                semanticWarning: "Sélectionne Filter comme Color FX sur le canal 2 avant le test."
            )
        default:
            return nil
        }
    }

    private func minimumVersion(for action: SeratoAction) -> String? {
        switch action {
        case .browserFocus: "6.6.3"
        case .filterA, .filterB: "6.7.4"
        default: "5.3.0"
        }
    }

    private func isAvailable(installed: RekordboxSemanticVersion?, minimumVersion: String?) -> Bool {
        guard let minimumVersion, let minimum = RekordboxSemanticVersion(minimumVersion) else { return true }
        guard let installed else { return true }
        return installed >= minimum
    }
}

public struct RekordboxDeviceValidationStore: Sendable {
    public var directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func load(for target: RekordboxDeviceValidationTarget) throws -> RekordboxDeviceValidationReport? {
        let url = fileURL(for: target)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder.validationDecoder.decode(
            RekordboxDeviceValidationReport.self,
            from: Data(contentsOf: url)
        )
    }

    public func save(_ report: RekordboxDeviceValidationReport) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.validationEncoder.encode(report)
        let url = fileURL(for: report.target)
        try data.write(to: url, options: .atomic)
        guard try Data(contentsOf: url) == data else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    public func remove(for target: RekordboxDeviceValidationTarget) throws {
        let url = fileURL(for: target)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func fileURL(for target: RekordboxDeviceValidationTarget) -> URL {
        directory.appendingPathComponent("\(target.identifier).json")
    }
}

private extension JSONEncoder {
    static var validationEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var validationDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
