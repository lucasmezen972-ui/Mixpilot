#if os(macOS)
import Foundation
import Security

protocol MixPilotRemoteTokenStoring: Sendable {
    func read(deviceID: String) -> String?
    func save(_ token: String, deviceID: String) throws
    func remove(deviceID: String) throws
}

struct MixPilotRemoteKeychainStore: MixPilotRemoteTokenStoring, @unchecked Sendable {
    private let service = "com.mixpilot.autopilot.remote"

    func read(deviceID: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ token: String, deviceID: String) throws {
        let data = Data(token.utf8)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw MixPilotRemotePairingError.keychain(updateStatus)
        }
        var insertion = lookup
        insertion[kSecValueData as String] = data
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw MixPilotRemotePairingError.keychain(addStatus)
        }
    }

    func remove(deviceID: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: deviceID,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MixPilotRemotePairingError.keychain(status)
        }
    }
}

enum MixPilotRemotePairingError: Error, LocalizedError {
    case invalidCode
    case expiredCode
    case tooManyAttempts(retryAfter: TimeInterval)
    case keychain(OSStatus)
    case randomGeneration

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            "Code d’appairage incorrect."
        case .expiredCode:
            "Le code d’appairage a expiré."
        case .tooManyAttempts(let retryAfter):
            "Trop de tentatives. Réessaie dans environ \(max(1, Int(retryAfter.rounded(.up)))) secondes."
        case .keychain(let status):
            "Erreur Trousseau macOS (\(status))."
        case .randomGeneration:
            "Impossible de générer un secret sécurisé. L’appairage reste désactivé."
        }
    }
}

@MainActor
final class MixPilotRemotePairingAuthority {
    struct CommandAuthorization {
        let allowed: Bool
        let message: String
    }

    private let tokenStore: any MixPilotRemoteTokenStoring
    private(set) var pairingCode = "------"
    private(set) var pairingExpiresAt = Date.distantPast
    private(set) var failedPairingAttempts = 0
    private(set) var pairingLockedUntil = Date.distantPast
    private var seenCommands: [UUID: Date] = [:]
    private let primaryDeviceAccount = "__mixpilot_primary_device__"
    private let maximumPairingAttempts = 5
    private let pairingLockoutDuration: TimeInterval = 300

    init(tokenStore: any MixPilotRemoteTokenStoring = MixPilotRemoteKeychainStore()) {
        self.tokenStore = tokenStore
    }

    @discardableResult
    func rotatePairingCode(now: Date = Date()) -> String {
        do {
            pairingCode = try Self.securePIN()
            pairingExpiresAt = now.addingTimeInterval(120)
            failedPairingAttempts = 0
            pairingLockedUntil = .distantPast
        } catch {
            pairingCode = "------"
            pairingExpiresAt = .distantPast
        }
        return pairingCode
    }

    func pair(deviceID: String, pin: String, now: Date = Date()) throws -> String {
        guard now >= pairingLockedUntil else {
            throw MixPilotRemotePairingError.tooManyAttempts(
                retryAfter: pairingLockedUntil.timeIntervalSince(now)
            )
        }
        guard now <= pairingExpiresAt else { throw MixPilotRemotePairingError.expiredCode }
        guard Self.constantTimeEqual(pin, pairingCode) else {
            failedPairingAttempts += 1
            if failedPairingAttempts >= maximumPairingAttempts {
                pairingLockedUntil = now.addingTimeInterval(pairingLockoutDuration)
                pairingExpiresAt = .distantPast
                pairingCode = "------"
                throw MixPilotRemotePairingError.tooManyAttempts(retryAfter: pairingLockoutDuration)
            }
            throw MixPilotRemotePairingError.invalidCode
        }

        let token = try Self.secureToken()
        try tokenStore.save(token, deviceID: deviceID)
        if tokenStore.read(deviceID: primaryDeviceAccount) == nil {
            try tokenStore.save(deviceID, deviceID: primaryDeviceAccount)
        }
        rotatePairingCode(now: now)
        return token
    }

    func authenticate(deviceID: String, token: String) -> Bool {
        guard let stored = tokenStore.read(deviceID: deviceID) else { return false }
        return Self.constantTimeEqual(stored, token)
    }

    func isPrimary(deviceID: String) -> Bool {
        tokenStore.read(deviceID: primaryDeviceAccount) == deviceID
    }

    func authorize(command: MixPilotRemoteCommand, deviceID: String, now: Date = Date()) -> CommandAuthorization {
        pruneSeenCommands(now: now)
        guard isPrimary(deviceID: deviceID) else {
            return .init(allowed: false, message: "Cet iPhone est connecté en lecture seule.")
        }
        guard abs(now.timeIntervalSince(command.issuedAt)) <= 10 else {
            return .init(allowed: false, message: "Commande expirée : elle n’a pas été exécutée.")
        }
        guard seenCommands[command.id] == nil else {
            return .init(allowed: false, message: "Commande déjà reçue : aucune double exécution.")
        }
        seenCommands[command.id] = now
        return .init(allowed: true, message: "Commande autorisée")
    }

    func revoke(deviceID: String) throws {
        try tokenStore.remove(deviceID: deviceID)
        if isPrimary(deviceID: deviceID) {
            try tokenStore.remove(deviceID: primaryDeviceAccount)
        }
    }

    private func pruneSeenCommands(now: Date) {
        seenCommands = seenCommands.filter { now.timeIntervalSince($0.value) < 300 }
        if seenCommands.count > 500 {
            let retained = seenCommands.sorted { $0.value > $1.value }.prefix(250)
            seenCommands = Dictionary(uniqueKeysWithValues: retained.map { ($0.key, $0.value) })
        }
    }

    private static func securePIN() throws -> String {
        var value: UInt32 = 0
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw MixPilotRemotePairingError.randomGeneration
        }
        return String(format: "%06d", Int(value % 1_000_000))
    }

    private static func secureToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw MixPilotRemotePairingError.randomGeneration
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices { difference |= left[index] ^ right[index] }
        return difference == 0
    }
}
#endif
