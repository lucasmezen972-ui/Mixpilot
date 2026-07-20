#if os(macOS)
import Foundation
import XCTest

final class CloudCommandDatabaseContractTests: XCTestCase {
    func testMigrationClosesDirectAuthenticatedUpdates() throws {
        let source = try migrationSource()
        XCTAssertTrue(source.contains(
            "revoke update on table public.mixpilot_commands from authenticated"
        ))
        XCTAssertTrue(source.contains("security definer"))
        XCTAssertTrue(source.contains("owner_id = auth.uid()"))
        XCTAssertTrue(source.contains("claimed_by_instance = p_instance_id"))
        XCTAssertTrue(source.contains(
            "Pending commands must be claimed before completion"
        ))
    }

    func testOnlyAtomicRPCsRemainExecutableForAuthenticatedRole() throws {
        let source = try migrationSource()
        XCTAssertTrue(source.contains(
            "grant execute on function public.claim_mixpilot_commands"
        ))
        XCTAssertTrue(source.contains(
            "grant execute on function public.complete_mixpilot_command"
        ))
        XCTAssertTrue(source.contains(
            "authenticated must not retain direct UPDATE on mixpilot_commands"
        ))
        XCTAssertTrue(source.contains(
            "command RPCs must remain SECURITY DEFINER"
        ))
    }

    private func migrationSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(
                "supabase/migrations/20260718143000_close_direct_command_updates.sql"
            ),
            encoding: .utf8
        )
    }
}
#endif
