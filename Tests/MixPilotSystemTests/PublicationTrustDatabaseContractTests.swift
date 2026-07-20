#if os(macOS)
import Foundation
import XCTest

final class PublicationTrustDatabaseContractTests: XCTestCase {
    func testPublicationMigrationRequiresEd25519AndTrustedProvenance() throws {
        let source = try migration("20260718153000_require_ed25519_signature_shape.sql")

        XCTAssertTrue(source.contains("octet_length(decoded) = 64"))
        XCTAssertTrue(source.contains("Published mappings require a valid Ed25519 signature encoding"))
        XCTAssertTrue(source.contains("source_repository is distinct from 'lucasmezen972-ui/Mixpilot'"))
        XCTAssertTrue(source.contains("Stable mappings require real device validation"))
        XCTAssertTrue(source.contains("Published releases require a valid Ed25519 signature encoding"))
    }

    func testEventPolicyBindsSessionToOuterDevice() throws {
        let source = try migration("20260718154500_fix_event_session_rls_reference.sql")

        XCTAssertTrue(source.contains("s.device_id = mixpilot_events.device_id"))
        XCTAssertTrue(source.contains("policy_expression like '%s.device_id = s.device_id%'"))
        XCTAssertTrue(source.contains("contains a tautological session/device comparison"))
        XCTAssertTrue(source.contains("must bind the session to the outer event device"))
    }

    private func migration(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent("supabase/migrations/\(name)"),
            encoding: .utf8
        )
    }
}
#endif
