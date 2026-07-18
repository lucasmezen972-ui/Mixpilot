#if os(macOS)
import Foundation
@testable import MixPilotRemoteBridge
import XCTest

@MainActor
private final class LifecycleStateProvider: MixPilotRemoteStateProvider {
    private(set) var commandCount = 0

    func makeRemoteSnapshot(sequence: Int, now: Date) -> MixPilotRemoteSnapshot {
        MixPilotRemoteSnapshot(
            sequence: sequence,
            updatedAt: now,
            mode: .live,
            setName: "Lifecycle Test",
            currentTrack: nil,
            nextTrack: nil,
            elapsed: 0,
            duration: 0,
            transitionLabel: nil,
            transitionConfidence: nil,
            alert: nil,
            canPause: true,
            canResume: false,
            canSkipTransition: false,
            canSafeFade: false,
            canTakeManualControl: true
        )
    }

    func handleRemoteCommand(_ kind: MixPilotRemoteCommandKind) async -> MixPilotRemoteCommandDecision {
        commandCount += 1
        return .init(accepted: true, message: "Executed")
    }
}

final class RemoteMessageGateTests: XCTestCase {
    func testInvalidJSONAndWrongVersionAreRejected() {
        let gate = MixPilotRemoteMessageGate()

        switch gate.evaluate(Data("{not-json".utf8), authenticated: false) {
        case .accepted:
            XCTFail("Le JSON invalide ne doit jamais être accepté")
        case .rejected(let response):
            XCTAssertEqual(response.type, "error")
            XCTAssertTrue(response.message?.contains("JSON invalide") == true)
        }

        let wrongVersion = Data(#"{"version":99,"type":"hello"}"#.utf8)
        switch gate.evaluate(wrongVersion, authenticated: false) {
        case .accepted:
            XCTFail("La mauvaise version ne doit jamais être acceptée")
        case .rejected(let response):
            XCTAssertEqual(response.type, "error")
            XCTAssertTrue(response.message?.contains("Version") == true)
        }
    }

    func testCommandAndSubscriptionBeforeAuthenticationAreRejected() {
        let gate = MixPilotRemoteMessageGate()
        let date = ISO8601DateFormatter().string(from: Date())
        let command = Data("""
        {"version":1,"type":"command","command":{"id":"\(UUID().uuidString)","kind":"takeManualControl","issuedAt":"\(date)"}}
        """.utf8)

        switch gate.evaluate(command, authenticated: false) {
        case .accepted:
            XCTFail("Une commande avant authentification doit être refusée")
        case .rejected(let response):
            XCTAssertEqual(response.type, "error")
            XCTAssertTrue(response.message?.contains("non authentifiée") == true)
        }

        let subscribe = Data(#"{"version":1,"type":"subscribe","lastSequence":12}"#.utf8)
        switch gate.evaluate(subscribe, authenticated: false) {
        case .accepted:
            XCTFail("Un abonnement avant authentification doit être refusé")
        case .rejected(let response):
            XCTAssertEqual(response.type, "error")
            XCTAssertTrue(response.message?.contains("Authentification") == true)
        }

        switch gate.evaluate(command, authenticated: true) {
        case .accepted(let message):
            XCTAssertEqual(message.command?.kind, .takeManualControl)
        case .rejected:
            XCTFail("La commande authentifiée et valide doit franchir la porte protocolaire")
        }
    }
}

@MainActor
final class RemoteBridgeLifecycleTests: XCTestCase {
    func testListenerStartAndStopNeverInvokeBusinessCommands() async throws {
#if DEBUG
        setenv(MixPilotRemoteTransportSecurityPolicy.developmentOverrideKey, "1", 1)
        defer { unsetenv(MixPilotRemoteTransportSecurityPolicy.developmentOverrideKey) }

        let provider = LifecycleStateProvider()
        let bridge = MixPilotRemoteBridge()
        bridge.start(provider: provider)

        for _ in 0..<100 where !bridge.status.contains("active") {
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertTrue(bridge.isRunning)
        XCTAssertTrue(bridge.status.contains("active"), "Le listener doit publier un port local")
        XCTAssertEqual(provider.commandCount, 0)

        bridge.stop()
        XCTAssertFalse(bridge.isRunning)
        XCTAssertEqual(bridge.connectedClientCount, 0)
        XCTAssertEqual(provider.commandCount, 0, "L’arrêt réseau ne doit jamais modifier le Live Mac")
#else
        throw XCTSkip("Le transport WebSocket de développement est volontairement indisponible en Release.")
#endif
    }
}
#endif
