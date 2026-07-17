#if os(macOS)
import MixPilotCore
import MixPilotSystem

@MainActor
extension AppModel {
    var onlineBackendContext: MixPilotCloudBackendContext? {
        guard let selectedBackend,
              let descriptor = backendDescriptors.first(where: { $0.identifier == selectedBackend }) else {
            return nil
        }

        return MixPilotCloudBackendContext(
            identifier: selectedBackend,
            softwareVersion: descriptor.environment.softwareVersion,
            controllerName: "MixPilot Virtual Controller",
            mappingVersion: "profile-\(mappingProfile.schemaVersion)",
            mappingSHA256: try? MixPilotRemoteMappingValidator.profileSHA256(mappingProfile),
            capabilities: descriptor.capabilities,
            validationStatus: preflightReport.canStartLive ? "ready" : "configuration_required"
        )
    }
}
#endif
