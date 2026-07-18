import Foundation

/// Shared policy used by both the Mac bridge and the iPhone client while the
/// legacy WebSocket transport remains unencrypted.
///
/// The override intentionally exists only in Debug builds. Release builds must
/// fail closed even when the environment variable is injected.
public enum MixPilotRemoteTransportSecurityPolicy {
    public static let insecureDevelopmentOverrideKey = "MIXPILOT_ALLOW_INSECURE_REMOTE"

    public static var allowsInsecureDevelopmentTransport: Bool {
        allowsInsecureDevelopmentTransport(environment: ProcessInfo.processInfo.environment)
    }

    public static func allowsInsecureDevelopmentTransport(
        environment: [String: String]
    ) -> Bool {
#if DEBUG
        environment[insecureDevelopmentOverrideKey] == "1"
#else
        false
#endif
    }
}
