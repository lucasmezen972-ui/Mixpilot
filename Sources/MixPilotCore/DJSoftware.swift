import Foundation

public enum DJSoftware: String, Codable, CaseIterable, Identifiable, Sendable {
    case serato
    case djay

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .serato: "Serato DJ Pro"
        case .djay: "djay Pro"
        }
    }

    public var shortName: String {
        switch self {
        case .serato: "Serato"
        case .djay: "djay"
        }
    }

    public var capabilities: DJSoftwareCapabilities {
        switch self {
        case .serato:
            DJSoftwareCapabilities(
                spotifyLibrary: true,
                builtInAutomix: false,
                customMIDILearn: true,
                detailedDeckAutomation: true,
                preferredExecutionMode: .directDeckControl,
                validationStatus: .requiresDeviceValidation
            )
        case .djay:
            DJSoftwareCapabilities(
                spotifyLibrary: true,
                builtInAutomix: true,
                customMIDILearn: true,
                detailedDeckAutomation: false,
                preferredExecutionMode: .automixQueue,
                validationStatus: .requiresDeviceValidation
            )
        }
    }
}

public enum DJExecutionMode: String, Codable, CaseIterable, Sendable {
    case directDeckControl
    case automixQueue
}

public enum DJBackendValidationStatus: String, Codable, Sendable {
    case automatedSuccess = "AUTOMATED_SUCCESS"
    case requiresDeviceValidation = "REQUIRES_DEVICE_VALIDATION"
    case blockedByPlatform = "BLOCKED_BY_PLATFORM"
}

public struct DJSoftwareCapabilities: Codable, Hashable, Sendable {
    public var spotifyLibrary: Bool
    public var builtInAutomix: Bool
    public var customMIDILearn: Bool
    public var detailedDeckAutomation: Bool
    public var preferredExecutionMode: DJExecutionMode
    public var validationStatus: DJBackendValidationStatus

    public init(
        spotifyLibrary: Bool,
        builtInAutomix: Bool,
        customMIDILearn: Bool,
        detailedDeckAutomation: Bool,
        preferredExecutionMode: DJExecutionMode,
        validationStatus: DJBackendValidationStatus
    ) {
        self.spotifyLibrary = spotifyLibrary
        self.builtInAutomix = builtInAutomix
        self.customMIDILearn = customMIDILearn
        self.detailedDeckAutomation = detailedDeckAutomation
        self.preferredExecutionMode = preferredExecutionMode
        self.validationStatus = validationStatus
    }
}
