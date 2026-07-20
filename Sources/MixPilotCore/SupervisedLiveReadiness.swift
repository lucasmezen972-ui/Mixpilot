import Foundation

public struct LiveWarning: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String

    public init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public struct LiveBlocker: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String

    public init(id: String, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public enum SupervisedLiveReadiness: Codable, Hashable, Sendable {
    case ready
    case readyWithWarnings([LiveWarning])
    case blocked([LiveBlocker])

    public var canStart: Bool {
        switch self {
        case .ready, .readyWithWarnings:
            true
        case .blocked:
            false
        }
    }

    public var warnings: [LiveWarning] {
        guard case .readyWithWarnings(let warnings) = self else { return [] }
        return warnings
    }

    public var blockers: [LiveBlocker] {
        guard case .blocked(let blockers) = self else { return [] }
        return blockers
    }
}

public extension PreflightReport {
    /// Readiness for the degraded, supervised automatic mode.
    ///
    /// Only stable technical impossibilities block this mode. Missing observation,
    /// permissions, audio monitoring and unconfirmed device reactions remain visible
    /// warnings; the runtime still keeps its circuit breakers and manual handoff.
    var supervisedReadiness: SupervisedLiveReadiness {
        let absoluteBlockerIDs: Set<String> = [
            "dj-backend",
            "midi",
            "project",
            "transition-capabilities",
        ]

        var blockers: [LiveBlocker] = []
        var warnings: [LiveWarning] = []

        for item in items {
            switch item.status {
            case .passed:
                continue
            case .warning, .notTested:
                warnings.append(LiveWarning(
                    id: item.id,
                    title: item.title,
                    detail: item.detail
                ))
            case .failed:
                if absoluteBlockerIDs.contains(item.id) {
                    blockers.append(LiveBlocker(
                        id: item.id,
                        title: item.title,
                        detail: item.detail
                    ))
                } else {
                    warnings.append(LiveWarning(
                        id: item.id,
                        title: item.title,
                        detail: item.detail
                    ))
                }
            }
        }

        if !blockers.isEmpty {
            return .blocked(blockers)
        }
        if !warnings.isEmpty {
            return .readyWithWarnings(warnings)
        }
        return .ready
    }

    var canStartSupervisedLive: Bool {
        supervisedReadiness.canStart
    }
}
