import Foundation

public extension MIDIMappingProfile {
    var validationIdentifier: String {
        let rows = mappings.keys.sorted().compactMap { key -> String? in
            guard let value = mappings[key] else { return nil }
            return "\(key)|\(value.kind.rawValue)|\(value.channel)|\(value.number)|\(value.minimumRawValue)|\(value.maximumRawValue)|\(value.offRawValue)|\(value.isMomentary)"
        }
        let value = (["schema=\(schemaVersion)"] + rows).joined(separator: "\n")
        return "profile-\(schemaVersion)-\(MixPilotRemoteMappingValidator.sha256(Data(value.utf8)))"
    }

    var liveControlCoverageRatio: Double {
        let required = DJControlAction.automaticPresetCriticalActions
        guard !required.isEmpty else { return 1 }
        let compatible = required.filter { hasRuntimeCompatibleMapping(for: $0) }.count
        return Double(compatible) / Double(required.count)
    }
}
