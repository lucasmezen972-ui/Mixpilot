#if os(macOS)
import AppKit
import Foundation

public struct RekordboxEnvironmentStatus: Codable, Hashable, Sendable {
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var applicationName: String?
    public var bundleIdentifier: String?

    public init(
        isRunning: Bool,
        processIdentifier: Int32?,
        applicationName: String?,
        bundleIdentifier: String?
    ) {
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum RekordboxApplicationMatcher {
    public static func matches(name: String?, bundleIdentifier: String? = nil) -> Bool {
        let normalizedName = name?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let normalizedBundle = bundleIdentifier?.lowercased() ?? ""

        return normalizedName == "rekordbox" ||
            normalizedName.hasPrefix("rekordbox ") ||
            normalizedBundle.contains("rekordbox")
    }
}

@MainActor
public final class RekordboxEnvironmentProbe {
    public init() {}

    public func probe() -> RekordboxEnvironmentStatus {
        let application = NSWorkspace.shared.runningApplications.first { application in
            RekordboxApplicationMatcher.matches(
                name: application.localizedName,
                bundleIdentifier: application.bundleIdentifier
            )
        }
        return RekordboxEnvironmentStatus(
            isRunning: application != nil,
            processIdentifier: application?.processIdentifier,
            applicationName: application?.localizedName,
            bundleIdentifier: application?.bundleIdentifier
        )
    }
}
#endif
