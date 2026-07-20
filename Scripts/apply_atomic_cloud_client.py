#!/usr/bin/env python3
from pathlib import Path

path = Path("Sources/MixPilotSystem/MixPilotCloudService.swift")
source = path.read_text(encoding="utf-8")

new_markers = (
    'private let commandAgentInstanceID: String?',
    'rest/v1/rpc/claim_mixpilot_commands',
    'rest/v1/rpc/complete_mixpilot_command',
    'MixPilotCloudAgentIdentityStore().loadOrCreate()',
)

if all(marker in source for marker in new_markers) and 'path: "rest/v1/mixpilot_commands"' not in source:
    if "private struct CommandCompletionRow: Encodable" in source:
        raise SystemExit("legacy completion row remains in an otherwise migrated service")
    print("Atomic cloud command client already applied.")
    raise SystemExit(0)

replacements = [
    (
        '    private let installationID: UUID\n    private let encoder: JSONEncoder',
        '    private let installationID: UUID\n    private let commandAgentInstanceID: String?\n    private let encoder: JSONEncoder',
    ),
    (
        '        self.installationID = Self.loadInstallationID()\n\n        let encoder = JSONEncoder()',
        '        self.installationID = Self.loadInstallationID()\n        self.commandAgentInstanceID = try? MixPilotCloudAgentIdentityStore().loadOrCreate()\n\n        let encoder = JSONEncoder()',
    ),
    (
        '''    public func pendingCommands() async throws -> [MixPilotCloudCommand] {
        guard let context else { return [] }
        let authSession = try await authenticatedSession()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try await performRequest(
            path: "rest/v1/mixpilot_commands",
            method: "GET",
            accessToken: authSession.accessToken,
            queryItems: [
                URLQueryItem(name: "device_id", value: "eq.\\(context.deviceID.uuidString)"),
                URLQueryItem(name: "status", value: "eq.pending"),
                URLQueryItem(name: "expires_at", value: "gt.\\(formatter.string(from: Date()))"),
                URLQueryItem(name: "order", value: "created_at.asc"),
                URLQueryItem(name: "limit", value: "10")
            ]
        )
    }''',
        '''    /// Compatibility name kept for the coordinator while the implementation is
    /// now fully atomic: returned commands are already claimed by this Mac.
    public func pendingCommands() async throws -> [MixPilotCloudCommand] {
        guard let context else { return [] }
        guard let commandAgentInstanceID else {
            throw MixPilotCloudCommandError.agentIdentityUnavailable
        }
        let authSession = try await authenticatedSession()
        return try await performRequest(
            path: "rest/v1/rpc/claim_mixpilot_commands",
            method: "POST",
            accessToken: authSession.accessToken,
            body: MixPilotCloudCommandClaimRequest(
                deviceID: context.deviceID,
                instanceID: commandAgentInstanceID,
                limit: 10
            )
        )
    }''',
    ),
    (
        '''    public func completeCommand(
        _ command: MixPilotCloudCommand,
        succeeded: Bool,
        result: [String: String]
    ) async throws {
        let authSession = try await authenticatedSession()
        let _: EmptyResponse = try await performRequest(
            path: "rest/v1/mixpilot_commands",
            method: "PATCH",
            accessToken: authSession.accessToken,
            queryItems: [URLQueryItem(name: "id", value: "eq.\\(command.id.uuidString)")],
            prefer: "return=minimal",
            body: CommandCompletionRow(
                status: succeeded ? "completed" : "failed",
                completedAt: Date(),
                result: result
            )
        )
    }''',
        '''    public func completeCommand(
        _ command: MixPilotCloudCommand,
        succeeded: Bool,
        result: [String: String]
    ) async throws {
        guard let commandAgentInstanceID else {
            throw MixPilotCloudCommandError.agentIdentityUnavailable
        }
        let authSession = try await authenticatedSession()
        let completed: Bool = try await performRequest(
            path: "rest/v1/rpc/complete_mixpilot_command",
            method: "POST",
            accessToken: authSession.accessToken,
            body: MixPilotCloudCommandCompletionRequest(
                commandID: command.id,
                instanceID: commandAgentInstanceID,
                succeeded: succeeded,
                result: result,
                failureCode: succeeded ? nil : result["error"]
            )
        )
        guard completed else {
            throw MixPilotCloudCommandError.completionRejected
        }
    }''',
    ),
]

for old, new in replacements:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"unsafe replacement count {count} for {old[:90]!r}")
    source = source.replace(old, new, 1)

legacy_completion = '''private struct CommandCompletionRow: Encodable {
    let status: String
    let completedAt: Date
    let result: [String: String]
    enum CodingKeys: String, CodingKey {
        case status
        case completedAt = "completed_at"
        case result
    }
}

'''
if source.count(legacy_completion) != 1:
    raise SystemExit("legacy completion row shape changed")
source = source.replace(legacy_completion, "", 1)

for marker in new_markers:
    if marker not in source:
        raise SystemExit(f"required atomic marker missing: {marker}")
if 'path: "rest/v1/mixpilot_commands"' in source:
    raise SystemExit("legacy command-table endpoint still present")
if "private struct CommandCompletionRow: Encodable" in source:
    raise SystemExit("legacy completion type still present")

path.write_text(source, encoding="utf-8")
print("Applied atomic claim/complete RPC client.")
