import Foundation

public struct DJCommandValidationKey: Codable, Hashable, Sendable {
    public var backend: DJBackendIdentifier
    public var softwareVersion: String?
    public var controllerName: String?
    public var mappingVersion: String?
    public var action: DJControlAction

    public init(
        backend: DJBackendIdentifier,
        softwareVersion: String? = nil,
        controllerName: String? = nil,
        mappingVersion: String? = nil,
        action: DJControlAction
    ) {
        self.backend = backend
        self.softwareVersion = softwareVersion
        self.controllerName = controllerName
        self.mappingVersion = mappingVersion
        self.action = action
    }

    public var storageKey: String {
        [
            backend.rawValue,
            softwareVersion ?? "unknown-software",
            controllerName ?? "unknown-controller",
            mappingVersion ?? "unknown-mapping",
            action.rawValue
        ].joined(separator: "|")
    }

    public var isFullyQualifiedForLive: Bool {
        hasValue(softwareVersion) && hasValue(controllerName) && hasValue(mappingVersion)
    }

    private func hasValue(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum DJCommandValidationEvidence: String, Codable, Hashable, Sendable {
    case deviceConfirmed
    case automatedProbe
    case simulated
    case userRejected
}

public struct DJCommandValidationRecord: Codable, Hashable, Sendable {
    public var key: DJCommandValidationKey
    public var status: DJValidationStatus
    public var evidence: DJCommandValidationEvidence?
    public var validatedAt: Date
    public var detail: String?

    public init(
        key: DJCommandValidationKey,
        status: DJValidationStatus,
        evidence: DJCommandValidationEvidence? = nil,
        validatedAt: Date = Date(),
        detail: String? = nil
    ) {
        self.key = key
        self.status = status
        self.evidence = evidence
        self.validatedAt = validatedAt
        self.detail = detail
    }

    public var permitsLiveControl: Bool {
        guard status == .automatedSuccess, key.isFullyQualifiedForLive else { return false }
        if let evidence {
            return evidence == .deviceConfirmed
        }

        return detail == "DEVICE_CONFIRMED"
    }
}

public protocol DJCommandValidationStoring: Sendable {
    func record(_ record: DJCommandValidationRecord) async throws
    func validation(for key: DJCommandValidationKey) async -> DJCommandValidationRecord?
    func validations(for backend: DJBackendIdentifier) async -> [DJCommandValidationRecord]
    func removeValidations(for backend: DJBackendIdentifier) async throws
}

public actor InMemoryDJCommandValidationStore: DJCommandValidationStoring {
    private var records: [String: DJCommandValidationRecord]

    public init(records: [DJCommandValidationRecord] = []) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.key.storageKey, $0) })
    }

    public func record(_ record: DJCommandValidationRecord) async throws {
        records[record.key.storageKey] = record
    }

    public func validation(for key: DJCommandValidationKey) async -> DJCommandValidationRecord? {
        records[key.storageKey]
    }

    public func validations(for backend: DJBackendIdentifier) async -> [DJCommandValidationRecord] {
        records.values.filter { $0.key.backend == backend }
    }

    public func removeValidations(for backend: DJBackendIdentifier) async throws {
        records = records.filter { $0.value.key.backend != backend }
    }
}

public actor UserDefaultsDJCommandValidationStore: DJCommandValidationStoring {
    public static let defaultsKey = "MixPilotBackendCommandValidationsV1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func record(_ record: DJCommandValidationRecord) async throws {
        var records = loadRecords()
        records[record.key.storageKey] = record
        defaults.set(try encoder.encode(records), forKey: Self.defaultsKey)
    }

    public func validation(for key: DJCommandValidationKey) async -> DJCommandValidationRecord? {
        loadRecords()[key.storageKey]
    }

    public func validations(for backend: DJBackendIdentifier) async -> [DJCommandValidationRecord] {
        loadRecords().values.filter { $0.key.backend == backend }
    }

    public func removeValidations(for backend: DJBackendIdentifier) async throws {
        let filtered = loadRecords().filter { $0.value.key.backend != backend }
        defaults.set(try encoder.encode(filtered), forKey: Self.defaultsKey)
    }

    private func loadRecords() -> [String: DJCommandValidationRecord] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let records = try? decoder.decode([String: DJCommandValidationRecord].self, from: data) else {
            return [:]
        }
        return records
    }
}
