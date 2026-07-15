#if os(macOS)
import Foundation
import Network
@testable import MixPilotRemoteBridge
import XCTest

private struct LoopbackTimeout: Error {}

private func withLoopbackTimeout<T: Sendable>(
    _ duration: Duration = .seconds(5),
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw LoopbackTimeout()
        }
        guard let result = try await group.next() else { throw LoopbackTimeout() }
        group.cancelAll()
        return result
    }
}

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

private final class OneShotContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func resume(
        _ continuation: CheckedContinuation<Void, any Error>,
        result: Result<Void, any Error>
    ) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        continuation.resume(with: result)
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let oneShot = OneShotContinuation()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    oneShot.resume(continuation, result: .success(()))
                case .failed(let error):
                    oneShot.resume(continuation, result: .failure(error))
                case .cancelled:
                    oneShot.resume(continuation, result: .failure(CancellationError()))
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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: ()) }
                }
            )
        }
    }

    func receive() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, any Error>) in
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
        try await withLoopbackTimeout { try await client.start() }
        defer { client.close() }

        let greetingData = try await withLoopbackTimeout { try await client.receive() }
        let greeting = try decodeServer(greetingData)
        XCTAssertEqual(greeting.type, "hello")

        try await withLoopbackTimeout { try await client.send(Data("{not-json".utf8)) }
        let invalidJSONData = try await withLoopbackTimeout { try await client.receive() }
        let invalidJSON = try decodeServer(invalidJSONData)
        XCTAssertEqual(invalidJSON.type, "error")
        XCTAssertTrue(invalidJSON.message?.contains("JSON invalide") == true)

        try await withLoopbackTimeout {
            try await client.send(Data(#"{"version":99,"type":"hello"}"#.utf8))
        }
        let wrongVersionData = try await withLoopbackTimeout { try await client.receive() }
        let wrongVersion = try decodeServer(wrongVersionData)
        XCTAssertEqual(wrongVersion.type, "error")
        XCTAssertTrue(wrongVersion.message?.contains("Version") == true)

        let commandID = UUID()
        let issuedAt = ISO8601DateFormatter().string(from: Date())
        let unauthenticated = """
        {"version":1,"type":"command","command":{"id":"\(commandID.uuidString)","kind":"takeManualControl","issuedAt":"\(issuedAt)"}}
        """
        try await withLoopbackTimeout { try await client.send(Data(unauthenticated.utf8)) }
        let commandErrorData = try await withLoopbackTimeout { try await client.receive() }
        let commandError = try decodeServer(commandErrorData)
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
        throw LoopbackTimeout()
    }

    private func decodeServer(_ data: Data) throws -> MixPilotRemoteServerMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MixPilotRemoteServerMessage.self, from: data)
    }
}
#endif
