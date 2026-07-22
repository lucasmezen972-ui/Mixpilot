#if os(macOS)
import Foundation
import Security

protocol MixPilotCloudAgentIdentityStoring: Sendable {
    func loadOrCreate() throws -> String
}

// SAFETY: The store contains only immutable service/account identifiers.
// Keychain operations do not retain mutable Swift state across threads.
struct MixPilotCloudAgentIdentityStore: MixPilotCloudAgentIdentityStoring, @unchecked Sendable {
    private let service = "com.mixpilot.autopilot.cloud-agent"
    private let account = "command-agent-instance-id"

    func loadOrCreate() throws -> String {
        if let existing = read(), UUID(uuidString: existing) != nil {
            return existing
        }

        let value = UUID().uuidString.lowercased()
        let data = Data(value.utf8)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return value }
        guard updateStatus == errSecItemNotFound else {
            throw MixPilotCloudAgentIdentityError.keychain(updateStatus)
        }

        var insert = lookup
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MixPilotCloudAgentIdentityError.keychain(status)
        }
        return value
    }

    private func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

enum MixPilotCloudAgentIdentityError: Error, LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            "Le Trousseau macOS n’a pas pu créer l’identité de l’agent cloud (code \(status)). Les commandes de maintenance restent désactivées."
        }
    }
}
#endif
