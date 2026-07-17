#if os(macOS)
import AppKit
import Foundation

public struct DjayEnvironmentStatus: Codable, Hashable, Sendable {
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var applicationName: String?

    public init(isRunning: Bool, processIdentifier: Int32?, applicationName: String?) {
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
    }
}

public enum DjayApplicationMatcher {
    public static func matches(name: String?) -> Bool {
        let normalized = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return normalized == "djay" || normalized == "djay pro" || normalized.hasPrefix("djay pro ")
    }
}

@MainActor
public final class DjayEnvironmentProbe {
    public init() {}

    public func probe() -> DjayEnvironmentStatus {
        let application = NSWorkspace.shared.runningApplications.first { application in
            DjayApplicationMatcher.matches(name: application.localizedName)
        }
        return DjayEnvironmentStatus(
            isRunning: application != nil,
            processIdentifier: application?.processIdentifier,
            applicationName: application?.localizedName
        )
    }
}
#endif
