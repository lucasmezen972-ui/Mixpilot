#if os(macOS)
import MixPilotCore

public extension MixPilotCloudService {
    @available(*, deprecated, message: "Pass an explicit MixPilotCloudBackendContext")
    func connect(
        appVersion: String,
        appBuild: Int,
        rekordboxVersion: String?,
        liveMode: Bool
    ) async throws -> MixPilotCloudContext {
        let backend = legacySelectedBackendContext(rekordboxVersion: rekordboxVersion)
        return try await connect(
            appVersion: appVersion,
            appBuild: appBuild,
            backend: backend,
            liveMode: liveMode,
            telemetryEnabled: MixPilotOnlineDiagnosticsPreferences().isEnabled
        )
    }

    @available(*, deprecated, message: "Pass an explicit MixPilotCloudBackendContext")
    func heartbeat(
        appVersion: String,
        appBuild: Int,
        rekordboxVersion: String?,
        liveMode: Bool
    ) async throws {
        try await heartbeat(
            appVersion: appVersion,
            appBuild: appBuild,
            backend: legacySelectedBackendContext(rekordboxVersion: rekordboxVersion),
            liveMode: liveMode,
            telemetryEnabled: MixPilotOnlineDiagnosticsPreferences().isEnabled
        )
    }

    private func legacySelectedBackendContext(
        rekordboxVersion: String?
    ) -> MixPilotCloudBackendContext {
        let identifier: DJBackendIdentifier = switch DJSoftwareSelectionStore.current {
        case .djay: .djay
        case .rekordbox: .rekordbox
        case .serato: .serato
        }
        return MixPilotCloudBackendContext(
            identifier: identifier,
            softwareVersion: identifier == .rekordbox ? rekordboxVersion : nil,
            controllerName: "MixPilot Virtual Controller"
        )
    }
}
#endif
