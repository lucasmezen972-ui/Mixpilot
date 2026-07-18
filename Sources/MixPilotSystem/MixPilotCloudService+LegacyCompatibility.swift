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
        return try await connect(
            appVersion: appVersion,
            appBuild: appBuild,
            backend: legacyRekordboxContext(rekordboxVersion: rekordboxVersion),
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
            backend: legacyRekordboxContext(rekordboxVersion: rekordboxVersion),
            liveMode: liveMode,
            telemetryEnabled: MixPilotOnlineDiagnosticsPreferences().isEnabled
        )
    }

    /// This overload predates multi-backend support and only exposes a
    /// `rekordboxVersion` argument. Preserve source compatibility without reading
    /// any hidden global selection state; new callers must pass an explicit context.
    private func legacyRekordboxContext(
        rekordboxVersion: String?
    ) -> MixPilotCloudBackendContext {
        MixPilotCloudBackendContext(
            identifier: .rekordbox,
            softwareVersion: rekordboxVersion,
            controllerName: "MixPilot Virtual Controller"
        )
    }
}
#endif
