#if os(macOS)
import Foundation

public struct MixPilotCloudAccount: Equatable, Sendable {
    public let userID: UUID
    public let email: String?

    public init(userID: UUID, email: String?) {
        self.userID = userID
        self.email = email
    }
}

public enum MixPilotCloudIdentityState: Equatable, Sendable {
    case checking
    case signedOut
    case linkSent(email: String)
    case signedIn(MixPilotCloudAccount)
    case failed(message: String)

    public var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }
}

public enum MixPilotCloudIdentityError: Error, LocalizedError, Equatable {
    case signedOut
    case invalidEmail
    case invalidCallback
    case callbackRejected(String)

    public var errorDescription: String? {
        switch self {
        case .signedOut:
            "Connecte ton compte MixPilot pour utiliser les services en ligne facultatifs."
        case .invalidEmail:
            "Entre une adresse e-mail valide."
        case .invalidCallback:
            "Ce lien de connexion ne correspond pas à MixPilot."
        case .callbackRejected:
            "Le lien de connexion n’a pas pu être validé. Demande un nouveau lien."
        }
    }
}

public enum MixPilotCloudIdentityPolicy {
    public static let callbackURL = URL(string: "mixpilot-autopilot://auth/callback")!

    public static func normalizedEmail(_ rawValue: String) throws -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard value.count <= 254,
              let at = value.lastIndex(of: "@"),
              at != value.startIndex,
              value.index(after: at) < value.endIndex,
              value[value.index(after: at)...].contains("."),
              !value.contains(where: { $0.isWhitespace }) else {
            throw MixPilotCloudIdentityError.invalidEmail
        }
        return value
    }

    public static func acceptsCallback(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == callbackURL.scheme?.lowercased(),
              url.host?.lowercased() == callbackURL.host?.lowercased(),
              url.path == callbackURL.path else {
            return false
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .contains(where: { $0.name == "code" && !($0.value ?? "").isEmpty }) == true
    }
}
#endif
