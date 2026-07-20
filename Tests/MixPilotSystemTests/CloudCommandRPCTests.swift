#if os(macOS)
import Foundation
@testable import MixPilotSystem
import XCTest

final class CloudCommandRPCTests: XCTestCase {
    func testClaimPayloadUsesExactRPCArgumentNames() throws {
        let data = try JSONEncoder().encode(
            MixPilotCloudCommandClaimRequest(
                deviceID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                instanceID: "22222222-2222-2222-2222-222222222222",
                limit: 10
            )
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["p_device_id"] as? String, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(object["p_instance_id"] as? String, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(object["p_limit"] as? Int, 10)
    }

    func testCompletionPayloadBindsResultToClaimingInstance() throws {
        let data = try JSONEncoder().encode(
            MixPilotCloudCommandCompletionRequest(
                commandID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                instanceID: "22222222-2222-2222-2222-222222222222",
                succeeded: false,
                result: ["error": "command_not_allowlisted"],
                failureCode: "command_not_allowlisted"
            )
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["p_command_id"] as? String, "33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(object["p_instance_id"] as? String, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(object["p_succeeded"] as? Bool, false)
        XCTAssertEqual(object["p_failure_code"] as? String, "command_not_allowlisted")
        XCTAssertEqual(
            (object["p_result"] as? [String: String])?["error"],
            "command_not_allowlisted"
        )
    }

    func testCloudCommandClientHasNoLegacyTablePollingOrCompletionPatch() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let serviceURL = root.appendingPathComponent(
            "Sources/MixPilotSystem/MixPilotCloudService.swift"
        )
        let source = try String(contentsOf: serviceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("rest/v1/rpc/claim_mixpilot_commands"))
        XCTAssertTrue(source.contains("rest/v1/rpc/complete_mixpilot_command"))
        XCTAssertFalse(source.contains("path: \"rest/v1/mixpilot_commands\""))
        XCTAssertFalse(source.contains("URLQueryItem(name: \"status\", value: \"eq.pending\")"))
        XCTAssertFalse(source.contains("MixPilotCloudCommandCompletionRow"))
        XCTAssertTrue(source.contains("MixPilotCloudAgentIdentityStore().loadOrCreate()"))
    }

    func testAgentIdentityUsesDeviceOnlyKeychainProtection() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/MixPilotSystem/MixPilotCloudAgentIdentity.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(source.contains("kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly"))
        XCTAssertTrue(source.contains("command-agent-instance-id"))
    }
}
#endif
