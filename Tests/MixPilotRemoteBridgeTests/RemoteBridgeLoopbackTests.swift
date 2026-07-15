#if os(macOS)
import Foundation
import Network
@testable import MixPilotRemoteBridge
import XCTest

@MainActor
private final class LoopbackStateProvider: MixPilotRemoteStateProvider {
    private(set) var commandCount = 0

    func makeRemoteSnapshot(sequence: Int, now: Date) -> MixPilotRemoteSnapshot {
        MixPilotRemoteSnapshot(
            sequence: sequence,
            updatedAt: now,
            mode: .live,
            setName: "Loopback Test",
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

private final class LoopbackWebSocketClient: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.mixpilot.tests.loopback-client")

    init(port: UInt16) {
        let parameters = NWParameters.tcp
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        connection = NWConnection(
            host: .ipv4(IPv4Address("127.0.0.1")!),
            port: NWEndpoint.Port(rawValue: port)!,
            using: parameters
        )
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var resumed = false
            connection.stateUpdateHandler = { state in
                lock.lock()
                defer { lock.unlock() }
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    continuation.resume()
                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ data: Data) async throws {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(
            identifier: UUID().uuidString,
            metadata: [metadata]
        )
        try await withCheckedThrowingContinuation { continuation in
            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            )
        }
    }

    func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { data, _, _, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: CancellationError()) }
            }
        }
    }

    func close() {
        connection.cancel()
    }
}

@MainActor
final class RemoteBridgeLoopbackTests: XCTestCase {
    func testInvalidVersionAndUnauthenticatedCommandAreRejectedWithoutProviderAction() async throws {
        let provider = LoopbackStateProvider()
        let bridge = MixPilotRemoteBridge()
        bridge.start(provider: provider)
        defer { bridge.stop() }

        let port = try await waitForPort(bridge)
        let client = LoopbackWebSocketClient(port: port)
        try await client.start()
        defer { client.close() }

        let greeting = try decodeServer(try await client.receive())
        XCTAssertEqual(greeting.type, "hello")

        try await client.send(Data("{not-json".utf8))
        let invalidJSON = try decodeServer(try await client.receive())
        XCTAssertEqual(invalidJSON.type, "error")
        XCTAssertTrue(invalidJSON.message?.contains("JSON invalide") == true)

        try await client.send(Data(#"{"version":99,"type":"hello"}"#.utf8))
        let wrongVersion = try decodeServer(try await client.receive())
        XCTAssertEqual(wrongVersion.type, "error")
        XCTAssertTrue(wrongVersion.message?.contains("Version") == true)

        let commandID = UUID()
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let unauthenticated = """
        {"version":1,"type":"command","command":{"id":"\(commandID.uuidString)","kind":"takeManualControl","issuedAt":"\(issuedAt)"}}
        """
        try await client.send(Data(unauthenticated.utf8))
        let commandError = try decodeServer(try await client.receive())
        XCTAssertEqual(commandError.type, "error")
        XCTAssertTrue(commandError.message?.contains("non authentifiée") == true)
        XCTAssertEqual(provider.commandCount, 0)

        bridge.stop()
        XCTAssertFalse(bridge.isRunning)
        XCTAssertEqual(provider.commandCount, 0)
    }

    private func waitForPort(_ bridge: MixPilotRemoteBridge) async throws -> UInt16 {
        for _ in 0..<100 {
            if let component = bridge.status.split(separator: " ").last,
               let port = UInt16(component) {
                return port
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Le listener WebSocket n’a pas publié son port")
        throw CancellationError()
    }

    private func decodeServer(_ data: Data) throws -> MixPilotRemoteServerMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MixPilotRemoteServerMessage.self, from: data)
    }
}
#endif
