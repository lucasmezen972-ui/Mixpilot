import Foundation
#if os(macOS)
import Darwin
#endif

public struct DJValidationPlatformContext: Codable, Hashable, Sendable {
    public var operatingSystemVersion: String?
    public var hardwareModel: String?
    public var appBuild: String?

    public init(
        operatingSystemVersion: String?,
        hardwareModel: String?,
        appBuild: String?
    ) {
        self.operatingSystemVersion = operatingSystemVersion
        self.hardwareModel = hardwareModel
        self.appBuild = appBuild
    }

    public static var current: Self {
        Self(
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hardwareModel: currentHardwareModel(),
            appBuild: currentAppBuild()
        )
    }

    public var isFullyQualified: Bool {
        hasValue(operatingSystemVersion) && hasValue(hardwareModel) && hasValue(appBuild)
    }

    private func hasValue(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func currentAppBuild() -> String? {
        if let bundleBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !bundleBuild.isEmpty {
            return bundleBuild
        }
        if let environmentBuild = ProcessInfo.processInfo.environment["MIXPILOT_BUILD_ID"],
           !environmentBuild.isEmpty {
            return environmentBuild
        }
        guard let executableURL = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return "development-\(Int(modificationDate.timeIntervalSince1970))"
    }

    private static func currentHardwareModel() -> String? {
        #if os(macOS)
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 1 else {
            return nil
        }
        var value = [CChar](repeating: 0, count: size)
        let result = value.withUnsafeMutableBytes { buffer in
            sysctlbyname("hw.model", buffer.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        return String(cString: value)
        #else
        return nil
        #endif
    }
}

public struct DJCommandValidationKey: Codable, Hashable, Sendable {
    public var backend: DJBackendIdentifier
    public var softwareVersion: String?
    public var controllerName: String?
    public var mappingVersion: String?
    public var operatingSystemVersion: String?
    public var hardwareModel: String?
    public var appBuild: String?
    public var action: DJControlAction

    public init(
        backend: DJBackendIdentifier,
        softwareVersion: String? = nil,
        controllerName: String? = nil,
        mappingVersion: String? = nil,
        action: DJControlAction,
        platformContext: DJValidationPlatformContext = .current
    ) {
        self.backend = backend
        self.softwareVersion = softwareVersion
        self.controllerName = controllerName
        self.mappingVersion = mappingVersion
        self.operatingSystemVersion = platformContext.operatingSystemVersion
        self.hardwareModel = platformContext.hardwareModel
        self.appBuild = platformContext.appBuild
        self.action = action
    }

    public var platformContext: DJValidationPlatformContext {
        DJValidationPlatformContext(
            operatingSystemVersion: operatingSystemVersion,
            hardwareModel: hardwareModel,
            appBuild: appBuild
        )
    }

    public var storageKey: String {
        [
            backend.rawValue,
            softwareVersion ?? "unknown-software",
            controllerName ?? "unknown-controller",
            mappingVersion ?? "unknown-mapping",
            operatingSystemVersion ?? "unknown-os",
            hardwareModel ?? "unknown-hardware",
            appBuild ?? "unknown-build",
            action.rawValue,
        ].joined(separator: "|")
    }

    public var isFullyQualifiedForLive: Bool {
        hasValue(softwareVersion) &&
            hasValue(controllerName) &&
            hasValue(mappingVersion) &&
            platformContext.isFullyQualified
    }

    public func matches(_ context: DJValidationPlatformContext) -> Bool {
        platformContext == context
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
        permitsLiveControl(in: .current)
    }

    public func permitsLiveControl(in context: DJValidationPlatformContext) -> Bool {
        guard status == .automatedSuccess,
              key.isFullyQualifiedForLive,
              key.matches(context) else {
            return false
        }
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
