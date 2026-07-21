#if os(macOS)
import Foundation
import MixPilotCore

// SAFETY: requiredHost and policy are immutable after initialization. URLSession
// delegate callbacks only read those values and never mutate shared Swift state.
private final class SpotifyRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let requiredHost: String
    private let policy = SpotifyNetworkPolicy()

    init(requiredHost: String) {
        self.requiredHost = requiredHost.lowercased()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let original = task.currentRequest?.url ?? task.originalRequest?.url,
              let destination = request.url,
              original.host?.lowercased() == requiredHost,
              destination.host?.lowercased() == requiredHost else {
            completionHandler(nil)
            return
        }
        do {
            try policy.validateRedirect(from: original, to: destination)
            completionHandler(request)
        } catch {
            completionHandler(nil)
        }
    }
}

actor SpotifyHTTPClient {
    private let policy = SpotifyNetworkPolicy()
    private let apiSession: URLSession
    private let tokenSession: URLSession

    init() {
        let apiConfiguration = URLSessionConfiguration.ephemeral
        apiConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        apiConfiguration.urlCache = nil
        apiConfiguration.httpCookieStorage = nil
        apiConfiguration.httpShouldSetCookies = false
        apiConfiguration.timeoutIntervalForRequest = 30
        apiConfiguration.timeoutIntervalForResource = 60

        let tokenConfiguration = URLSessionConfiguration.ephemeral
        tokenConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        tokenConfiguration.urlCache = nil
        tokenConfiguration.httpCookieStorage = nil
        tokenConfiguration.httpShouldSetCookies = false
        tokenConfiguration.timeoutIntervalForRequest = 30
        tokenConfiguration.timeoutIntervalForResource = 60

        apiSession = URLSession(
            configuration: apiConfiguration,
            delegate: SpotifyRedirectDelegate(requiredHost: SpotifyNetworkPolicy.apiHost),
            delegateQueue: nil
        )
        tokenSession = URLSession(
            configuration: tokenConfiguration,
            delegate: SpotifyRedirectDelegate(requiredHost: SpotifyNetworkPolicy.accountsHost),
            delegateQueue: nil
        )
    }

    func get<T: Decodable & Sendable>(
        _ type: T.Type,
        url: URL,
        accessToken: String
    ) async throws -> T {
        let request: URLRequest
        do {
            request = try policy.authorizedAPIRequest(url: url, accessToken: accessToken)
        } catch {
            throw SpotifyBridgeError.networkPolicy
        }
        let (data, response) = try await apiSession.data(for: request)
        try validate(response: response)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SpotifyBridgeError.invalidResponse
        }
    }

    func token(form: [String: String]) async throws -> SpotifyTokenResponse {
        guard let endpoint = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyBridgeError.invalidAuthorizationURL
        }
        let validatedEndpoint: URL
        do {
            validatedEndpoint = try policy.validatedTokenURL(endpoint)
        } catch {
            throw SpotifyBridgeError.networkPolicy
        }

        var request = URLRequest(url: validatedEndpoint)
        request.httpMethod = "POST"
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formEncoded(form)

        let (data, response) = try await tokenSession.data(for: request)
        try validate(response: response)
        do {
            let token = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            guard token.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
                  !token.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SpotifyBridgeError.invalidResponse
            }
            return token
        } catch let error as SpotifyBridgeError {
            throw error
        } catch {
            throw SpotifyBridgeError.invalidResponse
        }
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyBridgeError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 300..<400:
            throw SpotifyBridgeError.redirectRejected
        case 429:
            let seconds = Int(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 1
            throw SpotifyBridgeError.rateLimited(seconds: max(1, seconds))
        default:
            throw SpotifyBridgeError.api(status: http.statusCode)
        }
    }

    private func formEncoded(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encoded = values.keys.sorted().map { key in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            let encodedValue = values[key]?.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return Data(encoded.utf8)
    }
}
#endif
