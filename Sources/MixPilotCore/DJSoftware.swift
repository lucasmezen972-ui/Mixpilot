import Foundation

/// Legacy identifier preserved while older projects and preferences migrate to
/// `DJBackendIdentifier`. New runtime and UI code must use the backend registry.
@available(*, deprecated, renamed: "DJBackendIdentifier")
public enum DJSoftware: String, Codable, CaseIterable, Identifiable, Sendable {
    case serato
    case djay
    case rekordbox

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .serato: "Serato DJ Pro"
        case .djay: "djay Pro"
        case .rekordbox: "rekordbox"
        }
    }

    public var shortName: String {
        switch self {
        case .serato: "Serato"
        case .djay: "djay"
        case .rekordbox: "rekordbox"
        }
    }

    public var backendIdentifier: DJBackendIdentifier {
        switch self {
        case .serato: .serato
        case .djay: .djay
        case .rekordbox: .rekordbox
        }
    }

    public init(_ identifier: DJBackendIdentifier) {
        switch identifier {
        case .serato: self = .serato
        case .djay: self = .djay
        case .rekordbox: self = .rekordbox
        }
    }

    /// Historical six-flag model. It is intentionally not used for Live
    /// negotiation; the backend capability matrix is the source of truth.
    @available(*, deprecated, message: "Use DJBackendCapabilities from the active backend")
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
        case .rekordbox:
            DJSoftwareCapabilities(
                spotifyLibrary: true,
                builtInAutomix: false,
                customMIDILearn: true,
                detailedDeckAutomation: false,
                preferredExecutionMode: .directDeckControl,
                validationStatus: .requiresDeviceValidation
            )
        }
    }
}

public enum DJSoftwareSelectionStore {
    public static let defaultsKey = "MixPilotSelectedDJSoftware"

    /// Reads only an explicit legacy preference. Missing or invalid data returns
    /// nil so onboarding can ask the user instead of inventing Serato.
    public static var selected: DJSoftware? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: defaultsKey) else {
                return nil
            }
            return DJSoftware(rawValue: rawValue)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    public static func migrateToBackendIdentifier() -> DJBackendIdentifier? {
        selected?.backendIdentifier
    }
}

@available(*, deprecated, message: "Use DJBackendCapabilities")
public enum DJExecutionMode: String, Codable, CaseIterable, Sendable {
    case directDeckControl
    case automixQueue
}

@available(*, deprecated, message: "Use DJValidationStatus")
public enum DJBackendValidationStatus: String, Codable, Sendable {
    case automatedSuccess = "AUTOMATED_SUCCESS"
    case requiresDeviceValidation = "REQUIRES_DEVICE_VALIDATION"
    case blockedByPlatform = "BLOCKED_BY_PLATFORM"
}

@available(*, deprecated, message: "Use DJBackendCapabilities")
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
