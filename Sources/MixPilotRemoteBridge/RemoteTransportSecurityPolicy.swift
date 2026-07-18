import Foundation

public enum MixPilotRemoteTransportSecurityPolicy {
    public static let developmentOverrideKey = "MIXPILOT_ALLOW_INSECURE_REMOTE"

    /// The current WebSocket transport is intentionally unavailable unless an
    /// explicit development-only process environment override is supplied.
    /// Release builds always fail closed, even if the environment variable is
    /// injected, until TLS and device identity pinning are implemented.
    public static var allowsCurrentDevelopmentTransport: Bool {
        allowsCurrentDevelopmentTransport(environment: ProcessInfo.processInfo.environment)
    }

    public static func allowsCurrentDevelopmentTransport(
        environment: [String: String]
    ) -> Bool {
#if DEBUG
        environment[developmentOverrideKey] == "1"
#else
        false
#endif
    }
}
