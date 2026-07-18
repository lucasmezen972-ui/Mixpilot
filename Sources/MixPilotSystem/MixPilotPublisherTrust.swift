#if os(macOS)
import Foundation
import MixPilotCore

public enum MixPilotPublisherTrust {
    public static let bundleKey = "MixPilotPublisherPublicKey"
    public static let developmentEnvironmentKey = "MIXPILOT_PUBLISHER_PUBLIC_KEY_BASE64"

    public static func configuredPublicKey(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        if let bundled = bundle.object(forInfoDictionaryKey: bundleKey) as? String,
           isValidRawPublicKey(bundled) {
            return bundled
        }
#if DEBUG
        if let development = environment[developmentEnvironmentKey],
           isValidRawPublicKey(development) {
            return development
        }
#endif
        return nil
    }

    public static func verify(_ release: MixPilotCloudRelease) throws {
        try MixPilotPublisherVerification.verify(
            signatureBase64: release.signature,
            payload: MixPilotPublicationCanonicalizer.appRelease(release),
            publicKeyBase64: configuredPublicKey()
        )
    }

    public static func verify(_ release: MixPilotRemoteMappingRelease) throws {
        try MixPilotPublisherVerification.verify(
            signatureBase64: release.publisherSignature,
            payload: MixPilotPublicationCanonicalizer.mappingRelease(release),
            publicKeyBase64: configuredPublicKey()
        )
    }

    private static func isValidRawPublicKey(_ value: String) -> Bool {
        Data(base64Encoded: value)?.count == 32
    }
}
#endif
