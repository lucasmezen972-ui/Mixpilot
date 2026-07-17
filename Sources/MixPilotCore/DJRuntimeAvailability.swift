import Foundation

public extension DJBackendCapabilities {
    /// Returns the capabilities that are usable in the current macOS runtime.
    /// Historical validation evidence is preserved in storage, but a capability
    /// whose integration currently depends on Accessibility is not exposed as
    /// available while the permission is missing or revoked.
    func applyingRuntimeAvailability(accessibilityGranted: Bool) -> DJBackendCapabilities {
        guard !accessibilityGranted else { return self }

        var result = self
        for capability in DJCapability.allCases {
            let status = self[capability]
            guard status.method == .accessibility else { continue }

            result[capability] = DJCapabilityStatus(
                availability: .unavailable,
                confidence: status.confidence,
                validation: .requiresDeviceValidation,
                method: status.method,
                lastValidatedAt: status.lastValidatedAt,
                testedSoftwareVersion: status.testedSoftwareVersion,
                mappingVersion: status.mappingVersion,
                controllerName: status.controllerName,
                reason: "L’autorisation Accessibilité n’est pas disponible actuellement. Réactive-la dans Réglages Système, puis relance la vérification.",
                userAction: DJUserAction(
                    title: "Autoriser l’Accessibilité",
                    instructions: "Ouvre Réglages Système → Confidentialité et sécurité → Accessibilité, autorise MixPilot, puis relance le test."
                )
            )
        }
        return result
    }
}
