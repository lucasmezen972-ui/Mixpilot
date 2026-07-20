import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum SpotifyNetworkSecurityError: Error, Equatable, Sendable {
    case insecureScheme
    case unexpectedHost
    case credentialsInURL
    case invalidTokenEndpoint
    case crossHostRedirect
    case paginationLoop
    case pageLimitExceeded
    case emptyAccessToken
}

public struct SpotifyNetworkPolicy: Sendable {
    public static let apiHost = "api.spotify.com"
    public static let accountsHost = "accounts.spotify.com"
    public static let tokenPath = "/api/token"

    public init() {}

    public func validatedAPIURL(_ url: URL) throws -> URL {
        try validateSecureURL(url, requiredHost: Self.apiHost)
    }

    public func validatedTokenURL(_ url: URL) throws -> URL {
        let validated = try validateSecureURL(url, requiredHost: Self.accountsHost)
        guard validated.path == Self.tokenPath,
              validated.query == nil,
              validated.fragment == nil else {
            throw SpotifyNetworkSecurityError.invalidTokenEndpoint
        }
        return validated
    }

    public func authorizedAPIRequest(
        url: URL,
        accessToken: String,
        method: String = "GET"
    ) throws -> URLRequest {
        let validated = try validatedAPIURL(url)
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw SpotifyNetworkSecurityError.emptyAccessToken
        }
        var request = URLRequest(url: validated)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    public func validateRedirect(from original: URL, to destination: URL) throws {
        guard original.scheme?.lowercased() == "https",
              destination.scheme?.lowercased() == "https" else {
            throw SpotifyNetworkSecurityError.insecureScheme
        }
        guard original.host?.lowercased() == destination.host?.lowercased() else {
            throw SpotifyNetworkSecurityError.crossHostRedirect
        }
        _ = try validateSecureURL(destination, requiredHost: original.host?.lowercased() ?? "")
    }

    private func validateSecureURL(_ url: URL, requiredHost: String) throws -> URL {
        guard url.scheme?.lowercased() == "https" else {
            throw SpotifyNetworkSecurityError.insecureScheme
        }
        guard url.host?.lowercased() == requiredHost.lowercased() else {
            throw SpotifyNetworkSecurityError.unexpectedHost
        }
        guard url.user == nil, url.password == nil else {
            throw SpotifyNetworkSecurityError.credentialsInURL
        }
        guard url.port == nil || url.port == 443 else {
            throw SpotifyNetworkSecurityError.unexpectedHost
        }
        return url
    }
}

public struct SpotifyPaginationGuard: Sendable {
    public let maximumPages: Int
    private var seenURLs: Set<String> = []
    private(set) public var acceptedPageCount = 0

    public init(maximumPages: Int = 100) {
        self.maximumPages = max(1, maximumPages)
    }

    public mutating func accept(
        _ url: URL,
        policy: SpotifyNetworkPolicy = SpotifyNetworkPolicy()
    ) throws -> URL {
        let validated = try policy.validatedAPIURL(url)
        let canonical = canonicalString(for: validated)
        guard seenURLs.insert(canonical).inserted else {
            throw SpotifyNetworkSecurityError.paginationLoop
        }
        guard acceptedPageCount < maximumPages else {
            throw SpotifyNetworkSecurityError.pageLimitExceeded
        }
        acceptedPageCount += 1
        return validated
    }

    private func canonicalString(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil
        return components.string ?? url.absoluteString
    }
}
