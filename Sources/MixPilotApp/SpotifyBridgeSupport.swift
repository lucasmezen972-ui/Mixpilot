#if os(macOS)
import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import MixPilotCore
import MixPilotSystem
import Security
import SwiftUI

struct SpotifyStoredSession: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var scopes: String?

    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 90
    }
}

struct SpotifyTokenStore: @unchecked Sendable {
    private let service = "com.mixpilot.autopilot.spotify"

    func read(clientID: String) -> SpotifyStoredSession? {
        guard !clientID.isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: clientID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SpotifyStoredSession.self, from: data)
    }

    func save(_ session: SpotifyStoredSession, clientID: String) throws {
        let data = try JSONEncoder().encode(session)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: clientID,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw SpotifyBridgeError.keychain(updateStatus)
        }
        var insertion = lookup
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SpotifyBridgeError.keychain(addStatus)
        }
    }

    func remove(clientID: String) throws {
        guard !clientID.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: clientID,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SpotifyBridgeError.keychain(status)
        }
    }
}

enum SpotifyBridgeError: Error, LocalizedError {
    case missingClientID
    case invalidAuthorizationURL
    case authorizationCancelled
    case invalidCallback
    case stateMismatch
    case missingAuthorizationCode
    case randomGeneration
    case keychain(OSStatus)
    case invalidResponse
    case api(status: Int, message: String)
    case rateLimited(seconds: Int)
    case noRefreshToken
    case noPlaylistSelected
    case emptyPlaylist
    case backendNotSelected

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            "Renseigne l’identifiant Client ID de l’application Spotify MixPilot. Aucun Client Secret n’est nécessaire."
        case .invalidAuthorizationURL:
            "L’URL de connexion Spotify n’a pas pu être créée."
        case .authorizationCancelled:
            "La connexion Spotify a été annulée."
        case .invalidCallback:
            "Spotify a renvoyé une URL de retour invalide."
        case .stateMismatch:
            "La réponse Spotify ne correspond pas à la demande de connexion. Recommence la connexion."
        case .missingAuthorizationCode:
            "Spotify n’a pas renvoyé de code d’autorisation."
        case .randomGeneration:
            "Impossible de générer les secrets temporaires de connexion PKCE."
        case .keychain(let status):
            "Le Trousseau macOS a refusé l’enregistrement de la session Spotify (code \(status))."
        case .invalidResponse:
            "Spotify a renvoyé une réponse non reconnue."
        case .api(let status, let message):
            "Spotify a refusé la demande (HTTP \(status)) : \(message)"
        case .rateLimited(let seconds):
            "Spotify limite temporairement les requêtes. Réessaie dans environ \(seconds) seconde(s)."
        case .noRefreshToken:
            "La session Spotify a expiré et aucun jeton de renouvellement n’est disponible. Reconnecte le compte."
        case .noPlaylistSelected:
            "Choisis d’abord une playlist Spotify."
        case .emptyPlaylist:
            "Cette playlist ne contient aucun morceau exploitable dans MixPilot."
        case .backendNotSelected:
            "Choisis Rekordbox, Serato ou djay avant de vérifier ce que le logiciel affiche."
        }
    }
}

enum SpotifyPKCE {
    static func randomURLSafeString(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: max(32, byteCount))
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else { throw SpotifyBridgeError.randomGeneration }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct SpotifyTokenResponse: Decodable {
    var accessToken: String
    var tokenType: String
    var scope: String?
    var expiresIn: Int
    var refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

struct SpotifyProfileDTO: Decodable {
    var displayName: String?
    var id: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case id
    }
}

struct SpotifyPageDTO<Item: Decodable>: Decodable {
    var items: [Item]
    var next: String?
    var total: Int?
}

struct SpotifyExternalURLsDTO: Decodable {
    var spotify: URL?
}

struct SpotifyOwnerDTO: Decodable {
    var displayName: String?
    var id: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case id
    }
}

struct SpotifyCountDTO: Decodable {
    var total: Int?
}

struct SpotifyPlaylistDTO: Decodable {
    var id: String
    var name: String
    var owner: SpotifyOwnerDTO?
    var collaborative: Bool?
    var isPublic: Bool?
    var externalURLs: SpotifyExternalURLsDTO?
    var items: SpotifyCountDTO?
    var tracks: SpotifyCountDTO?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, collaborative, items, tracks
        case isPublic = "public"
        case externalURLs = "external_urls"
    }
}

struct SpotifyArtistDTO: Decodable {
    var name: String
}

struct SpotifyAlbumDTO: Decodable {
    var name: String?
}

struct SpotifyExternalIDsDTO: Decodable {
    var isrc: String?
}

struct SpotifyTrackDTO: Decodable {
    var id: String?
    var uri: String?
    var name: String
    var artists: [SpotifyArtistDTO]
    var album: SpotifyAlbumDTO?
    var durationMilliseconds: Int?
    var explicit: Bool?
    var isPlayable: Bool?
    var isLocal: Bool?
    var externalIDs: SpotifyExternalIDsDTO?
    var externalURLs: SpotifyExternalURLsDTO?

    enum CodingKeys: String, CodingKey {
        case id, uri, name, artists, album, explicit
        case durationMilliseconds = "duration_ms"
        case isPlayable = "is_playable"
        case isLocal = "is_local"
        case externalIDs = "external_ids"
        case externalURLs = "external_urls"
    }
}

struct SpotifyPlaylistItemDTO: Decodable {
    var item: SpotifyTrackDTO?
    var track: SpotifyTrackDTO?

    var resolvedTrack: SpotifyTrackDTO? { item ?? track }
}

#endif
