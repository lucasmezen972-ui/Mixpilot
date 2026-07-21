#if os(macOS)
import Foundation

extension SeratoMappingManifest {
    public static func == (
        lhs: SeratoMappingManifest,
        rhs: SeratoMappingManifest
    ) -> Bool {
        lhs.presetName == rhs.presetName
            && lhs.presetVersion == rhs.presetVersion
            && Int(lhs.installedAt.timeIntervalSince1970) == Int(rhs.installedAt.timeIntervalSince1970)
            && lhs.supportedActions == rhs.supportedActions
            && lhs.unsupportedActions == rhs.unsupportedActions
            && lhs.generatedXMLBytes == rhs.generatedXMLBytes
            && lhs.sourceNotice == rhs.sourceNotice
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(presetName)
        hasher.combine(presetVersion)
        hasher.combine(Int(installedAt.timeIntervalSince1970))
        hasher.combine(supportedActions)
        hasher.combine(unsupportedActions)
        hasher.combine(generatedXMLBytes)
        hasher.combine(sourceNotice)
    }
}
#endif
