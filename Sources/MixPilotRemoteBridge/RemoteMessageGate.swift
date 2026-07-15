#if os(macOS)
import Foundation

enum MixPilotRemoteMessageGateResult: Sendable {
    case accepted(MixPilotRemoteClientMessage)
    case rejected(MixPilotRemoteServerMessage)
}

struct MixPilotRemoteMessageGate: Sendable {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func evaluate(
        _ data: Data,
        authenticated: Bool
    ) -> MixPilotRemoteMessageGateResult {
        let message: MixPilotRemoteClientMessage
        do {
            message = try decoder.decode(MixPilotRemoteClientMessage.self, from: data)
        } catch {
            return .rejected(.simple("error", message: "Message JSON invalide."))
        }

        guard message.version == 1 else {
            return .rejected(.simple("error", message: "Version du protocole non compatible."))
        }

        if !authenticated {
            switch message.type {
            case "subscribe":
                return .rejected(.simple("error", message: "Authentification requise."))
            case "command":
                return .rejected(.simple("error", message: "Commande non authentifiée."))
            default:
                break
            }
        }

        return .accepted(message)
    }
}
#endif
