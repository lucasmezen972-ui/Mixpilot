#if os(macOS)
import Foundation

struct MixPilotCloudCommandClaimRequest: Encodable, Sendable {
    let deviceID: UUID
    let instanceID: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case deviceID = "p_device_id"
        case instanceID = "p_instance_id"
        case limit = "p_limit"
    }
}

struct MixPilotCloudCommandCompletionRequest: Encodable, Sendable {
    let commandID: UUID
    let instanceID: String
    let succeeded: Bool
    let result: [String: String]
    let failureCode: String?

    enum CodingKeys: String, CodingKey {
        case commandID = "p_command_id"
        case instanceID = "p_instance_id"
        case succeeded = "p_succeeded"
        case result = "p_result"
        case failureCode = "p_failure_code"
    }
}

enum MixPilotCloudCommandError: Error, LocalizedError {
    case agentIdentityUnavailable
    case completionRejected

    var errorDescription: String? {
        switch self {
        case .agentIdentityUnavailable:
            "L’identité locale de l’agent cloud est indisponible. Aucune commande de maintenance ne sera réclamée."
        case .completionRejected:
            "Le serveur a refusé la finalisation de cette commande. Son résultat n’a pas été réécrit."
        }
    }
}
#endif
