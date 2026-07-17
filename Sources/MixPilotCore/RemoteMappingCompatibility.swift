import Foundation

public extension MixPilotCompatibilityOverride {
    init(
        id: UUID,
        channel: String,
        backend: DJBackendIdentifier,
        controllerName: String,
        minimumAppBuild: Int,
        minimumSoftwareVersion: String?,
        maximumSoftwareVersion: String?,
        disabledActions: [String],
        requiredValidations: [String],
        warnings: [String],
        blockLive: Bool,
        rolloutPercentage: Int,
        publishedAt: Date
    ) {
        self.id = id
        self.channel = channel
        self.software = backend.rawValue
        self.controllerName = controllerName
        self.minimumAppBuild = minimumAppBuild
        self.minimumSoftwareVersion = minimumSoftwareVersion
        self.maximumSoftwareVersion = maximumSoftwareVersion
        self.disabledActions = disabledActions
        self.requiredValidations = requiredValidations
        self.warnings = warnings
        self.blockLive = blockLive
        self.rolloutPercentage = rolloutPercentage
        self.publishedAt = publishedAt
    }

    @available(*, deprecated, message: "Use the backend and generic software-version initializer")
    init(
        id: UUID,
        channel: String,
        software: String,
        controllerName: String,
        minimumAppBuild: Int,
        minimumRekordboxVersion: String?,
        maximumRekordboxVersion: String?,
        disabledActions: [String],
        requiredValidations: [String],
        warnings: [String],
        blockLive: Bool,
        rolloutPercentage: Int,
        publishedAt: Date
    ) {
        self.id = id
        self.channel = channel
        self.software = software
        self.controllerName = controllerName
        self.minimumAppBuild = minimumAppBuild
        self.minimumSoftwareVersion = minimumRekordboxVersion
        self.maximumSoftwareVersion = maximumRekordboxVersion
        self.disabledActions = disabledActions
        self.requiredValidations = requiredValidations
        self.warnings = warnings
        self.blockLive = blockLive
        self.rolloutPercentage = rolloutPercentage
        self.publishedAt = publishedAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(channel, forKey: .channel)
        try container.encode(software, forKey: .software)
        try container.encode(controllerName, forKey: .controllerName)
        try container.encode(minimumAppBuild, forKey: .minimumAppBuild)
        try container.encodeIfPresent(minimumSoftwareVersion, forKey: .minimumSoftwareVersion)
        try container.encodeIfPresent(maximumSoftwareVersion, forKey: .maximumSoftwareVersion)
        try container.encode(disabledActions, forKey: .disabledActions)
        try container.encode(requiredValidations, forKey: .requiredValidations)
        try container.encode(warnings, forKey: .warnings)
        try container.encode(blockLive, forKey: .blockLive)
        try container.encode(rolloutPercentage, forKey: .rolloutPercentage)
        try container.encode(publishedAt, forKey: .publishedAt)
    }
}
