import MixPilotRemoteProtocol
import XCTest
@testable import MixPilotRemote

@MainActor
final class RemoteConnectionTests: XCTestCase {
    func testDemoCommandsPreserveBackendDeckAndAudioContext() throws {
        let connection = RemoteConnection()
        connection.startDemo()

        let initial = try XCTUnwrap(connection.snapshot)
        let backend = try XCTUnwrap(initial.backend)
        let activeDeck = try XCTUnwrap(initial.activeDeck)
        let audioStatus = try XCTUnwrap(initial.audioStatus)

        for command in [
            RemoteCommandKind.pauseAutopilot,
            .resumeAutopilot,
            .skipTransition,
            .safeFade,
            .takeManualControl,
        ] {
            connection.startDemo()
            connection.sendCommand(command)

            let snapshot = try XCTUnwrap(connection.snapshot)
            XCTAssertEqual(snapshot.backend, backend)
            XCTAssertEqual(snapshot.activeDeck, activeDeck)
            XCTAssertEqual(snapshot.audioStatus, audioStatus)
        }
    }

    func testDemoCommandsRemainLocalSimulations() throws {
        let connection = RemoteConnection()
        connection.startDemo()
        connection.sendCommand(.pauseAutopilot)

        XCTAssertTrue(connection.isDemo)
        XCTAssertEqual(connection.lastAcknowledgement?.accepted, true)
        XCTAssertEqual(
            connection.lastAcknowledgement?.message,
            RemoteLocalizedCopy.text("remote.demo.command_simulated")
        )
        XCTAssertEqual(connection.snapshot?.mode, .paused)
    }
}
