import Foundation
import Testing
@testable import MixPilotCore

@Test("Bearer token is only built for api.spotify.com over HTTPS")
func spotifyBearerTokenNeverLeavesAPIHost() throws {
    let policy = SpotifyNetworkPolicy()
    let valid = try #require(URL(string: "https://api.spotify.com/v1/me"))
    let request = try policy.authorizedAPIRequest(url: valid, accessToken: "secret-token")

    #expect(request.url?.host == SpotifyNetworkPolicy.apiHost)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret-token")

    let foreign = try #require(URL(string: "https://example.com/v1/me"))
    #expect(throws: SpotifyNetworkSecurityError.unexpectedHost) {
        try policy.authorizedAPIRequest(url: foreign, accessToken: "secret-token")
    }

    let insecure = try #require(URL(string: "http://api.spotify.com/v1/me"))
    #expect(throws: SpotifyNetworkSecurityError.insecureScheme) {
        try policy.authorizedAPIRequest(url: insecure, accessToken: "secret-token")
    }
}

@Test("Spotify API redirects cannot change domain")
func spotifyRedirectCannotChangeDomain() throws {
    let policy = SpotifyNetworkPolicy()
    let original = try #require(URL(string: "https://api.spotify.com/v1/me"))
    let sameHost = try #require(URL(string: "https://api.spotify.com/v1/me?market=FR"))
    let foreign = try #require(URL(string: "https://attacker.example/v1/me"))

    try policy.validateRedirect(from: original, to: sameHost)
    #expect(throws: SpotifyNetworkSecurityError.crossHostRedirect) {
        try policy.validateRedirect(from: original, to: foreign)
    }
}

@Test("Spotify pagination loops are rejected")
func spotifyPaginationLoopIsStopped() throws {
    var guardrail = SpotifyPaginationGuard(maximumPages: 10)
    let url = try #require(URL(string: "https://api.spotify.com/v1/me/playlists?offset=0"))

    _ = try guardrail.accept(url)
    #expect(throws: SpotifyNetworkSecurityError.paginationLoop) {
        try guardrail.accept(url)
    }
}

@Test("Spotify pagination has a hard page limit")
func spotifyPaginationHasPageLimit() throws {
    var guardrail = SpotifyPaginationGuard(maximumPages: 2)
    let first = try #require(URL(string: "https://api.spotify.com/v1/me/playlists?offset=0"))
    let second = try #require(URL(string: "https://api.spotify.com/v1/me/playlists?offset=50"))
    let third = try #require(URL(string: "https://api.spotify.com/v1/me/playlists?offset=100"))

    _ = try guardrail.accept(first)
    _ = try guardrail.accept(second)
    #expect(throws: SpotifyNetworkSecurityError.pageLimitExceeded) {
        try guardrail.accept(third)
    }
}

@Test("Spotify token endpoint is exact and has no query")
func spotifyTokenEndpointIsExact() throws {
    let policy = SpotifyNetworkPolicy()
    let valid = try #require(URL(string: "https://accounts.spotify.com/api/token"))
    _ = try policy.validatedTokenURL(valid)

    let wrongPath = try #require(URL(string: "https://accounts.spotify.com/authorize"))
    #expect(throws: SpotifyNetworkSecurityError.invalidTokenEndpoint) {
        try policy.validatedTokenURL(wrongPath)
    }

    let query = try #require(URL(string: "https://accounts.spotify.com/api/token?redirect=1"))
    #expect(throws: SpotifyNetworkSecurityError.invalidTokenEndpoint) {
        try policy.validatedTokenURL(query)
    }
}
