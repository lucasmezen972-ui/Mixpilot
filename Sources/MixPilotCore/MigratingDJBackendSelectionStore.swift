import Foundation

public actor MigratingDJBackendSelectionStore: DJBackendSelectionStoring {
    public static let defaultsKey = "MixPilotSelectedDJBackendV2"
    public static let legacyDefaultsKey = "MixPilotSelectedDJSoftware"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSelection() async -> DJBackendIdentifier? {
        if let rawValue = defaults.string(forKey: Self.defaultsKey) {
            guard let identifier = DJBackendIdentifier(rawValue: rawValue) else {
                defaults.removeObject(forKey: Self.defaultsKey)
                defaults.removeObject(forKey: Self.legacyDefaultsKey)
                return nil
            }
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
            return identifier
        }

        guard let legacyValue = defaults.string(forKey: Self.legacyDefaultsKey),
              let migrated = DJBackendIdentifier(rawValue: legacyValue) else {
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
            return nil
        }

        defaults.set(migrated.rawValue, forKey: Self.defaultsKey)
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        return migrated
    }

    public func saveSelection(_ identifier: DJBackendIdentifier?) async throws {
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        if let identifier {
            defaults.set(identifier.rawValue, forKey: Self.defaultsKey)
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
        }
    }
}
