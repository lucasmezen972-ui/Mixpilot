import MixPilotRemoteProtocol

/// Compatibility facade for existing macOS call sites and tests.
public enum MixPilotRemoteTransportSecurityPolicy {
    public static let developmentOverrideKey =
        MixPilotRemoteProtocol.MixPilotRemoteTransportSecurityPolicy.insecureDevelopmentOverrideKey

    public static var allowsCurrentDevelopmentTransport: Bool {
        MixPilotRemoteProtocol.MixPilotRemoteTransportSecurityPolicy
            .allowsInsecureDevelopmentTransport
    }

    public static func allowsCurrentDevelopmentTransport(
        environment: [String: String]
    ) -> Bool {
        MixPilotRemoteProtocol.MixPilotRemoteTransportSecurityPolicy
            .allowsInsecureDevelopmentTransport(environment: environment)
    }
}
