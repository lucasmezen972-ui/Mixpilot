import Foundation

public struct DjayAccessibilityNode: Identifiable, Codable, Hashable, Sendable {
    public var id: String { path }

    public var path: String
    public var depth: Int
    public var role: String
    public var subrole: String?
    public var identifier: String?
    public var title: String?
    public var value: String?
    public var nodeDescription: String?
    public var help: String?
    public var enabled: Bool?
    public var focused: Bool?
    public var selected: Bool?
    public var actions: [String]
    public var context: [String]

    public init(
        path: String,
        depth: Int,
        role: String,
        subrole: String? = nil,
        identifier: String? = nil,
        title: String? = nil,
        value: String? = nil,
        nodeDescription: String? = nil,
        help: String? = nil,
        enabled: Bool? = nil,
        focused: Bool? = nil,
        selected: Bool? = nil,
        actions: [String] = [],
        context: [String] = []
    ) {
        self.path = path
        self.depth = depth
        self.role = role
        self.subrole = subrole
        self.identifier = identifier
        self.title = title
        self.value = value
        self.nodeDescription = nodeDescription
        self.help = help
        self.enabled = enabled
        self.focused = focused
        self.selected = selected
        self.actions = actions
        self.context = context
    }

    public var visibleStrings: [String] {
        [title, value, nodeDescription, help, identifier]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public var searchableText: String {
        (visibleStrings + context + [role, subrole].compactMap { $0 })
            .joined(separator: " ")
    }
}

public enum DjayAutomixCandidateKind: String, Codable, CaseIterable, Sendable {
    case automixContainer
    case queueRow
    case automixControl
    case playbackControl
    case addToQueueControl
}

public struct DjayAutomixCandidate: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(kind.rawValue)|\(nodePath)" }

    public var nodePath: String
    public var kind: DjayAutomixCandidateKind
    public var score: Int
    public var label: String
    public var reasons: [String]

    public init(
        nodePath: String,
        kind: DjayAutomixCandidateKind,
        score: Int,
        label: String,
        reasons: [String]
    ) {
        self.nodePath = nodePath
        self.kind = kind
        self.score = min(max(score, 0), 100)
        self.label = label
        self.reasons = reasons
    }
}

public struct DjayAutomixReadinessReport: Codable, Hashable, Sendable {
    public var totalNodeCount: Int
    public var candidates: [DjayAutomixCandidate]
    public var confidence: Int
    public var validationStatus: DJBackendValidationStatus
    public var summary: String

    public init(
        totalNodeCount: Int,
        candidates: [DjayAutomixCandidate],
        confidence: Int,
        validationStatus: DJBackendValidationStatus,
        summary: String
    ) {
        self.totalNodeCount = totalNodeCount
        self.candidates = candidates
        self.confidence = min(max(confidence, 0), 100)
        self.validationStatus = validationStatus
        self.summary = summary
    }

    public var automixContainers: [DjayAutomixCandidate] {
        candidates.filter { $0.kind == .automixContainer }
    }

    public var queueRows: [DjayAutomixCandidate] {
        candidates.filter { $0.kind == .queueRow }
    }

    public var controls: [DjayAutomixCandidate] {
        candidates.filter {
            $0.kind == .automixControl ||
                $0.kind == .playbackControl ||
                $0.kind == .addToQueueControl
        }
    }

    public var hasReadOnlyAutomixEvidence: Bool {
        !automixContainers.isEmpty || !queueRows.isEmpty
    }
}

public struct DjayAutomixQueueAnalyzer: Sendable {
    public init() {}

    public func analyze(nodes: [DjayAccessibilityNode]) -> DjayAutomixReadinessReport {
        var candidates: [DjayAutomixCandidate] = []

        for node in nodes {
            let normalizedText = Self.normalize(node.searchableText)
            let normalizedRole = Self.normalize(node.role)
            let isControl = Self.containsAny(normalizedRole, ["button", "checkbox", "switch", "menuitem", "radiobutton"])
            let isContainer = Self.containsAny(normalizedRole, ["group", "scrollarea", "table", "outline", "list"])
            let isRow = Self.containsAny(normalizedRole, ["row", "cell", "outlineitem"])
            let mentionsAutomix = Self.containsAny(normalizedText, ["automix", "auto mix"])
            let mentionsQueue = Self.containsAny(normalizedText, [
                "queue", "file d attente", "a suivre", "up next", "next songs", "playlist automix"
            ])

            if isContainer && (mentionsAutomix || mentionsQueue) {
                candidates.append(.init(
                    nodePath: node.path,
                    kind: .automixContainer,
                    score: mentionsAutomix && mentionsQueue ? 95 : 82,
                    label: Self.bestLabel(for: node, fallback: "Conteneur Automix potentiel"),
                    reasons: [
                        "rôle de conteneur accessible",
                        mentionsAutomix ? "libellé Automix détecté" : "libellé de file détecté",
                    ]
                ))
            }

            if isRow && (mentionsAutomix || mentionsQueue) {
                var score = 68
                var reasons = ["rôle de ligne ou cellule"]
                if node.visibleStrings.count >= 2 {
                    score += 12
                    reasons.append("plusieurs champs visibles")
                }
                if node.selected != nil {
                    score += 5
                    reasons.append("état de sélection exposé")
                }
                candidates.append(.init(
                    nodePath: node.path,
                    kind: .queueRow,
                    score: score,
                    label: Self.bestLabel(for: node, fallback: "Ligne Automix potentielle"),
                    reasons: reasons
                ))
            }

            if isControl && mentionsAutomix {
                candidates.append(.init(
                    nodePath: node.path,
                    kind: .automixControl,
                    score: 88,
                    label: Self.bestLabel(for: node, fallback: "Commande Automix potentielle"),
                    reasons: ["contrôle accessible", "libellé Automix détecté"]
                ))
            }

            if isControl && Self.containsAny(normalizedText, ["play", "lecture", "demarrer", "start", "resume", "reprendre"]) {
                candidates.append(.init(
                    nodePath: node.path,
                    kind: .playbackControl,
                    score: mentionsAutomix ? 90 : 62,
                    label: Self.bestLabel(for: node, fallback: "Commande de lecture potentielle"),
                    reasons: mentionsAutomix
                        ? ["contrôle accessible", "lecture et Automix mentionnés"]
                        : ["contrôle accessible", "libellé de lecture détecté"]
                ))
            }

            if isControl && Self.containsAny(normalizedText, ["add to queue", "add to automix", "ajouter a la file", "ajouter a automix"]) {
                candidates.append(.init(
                    nodePath: node.path,
                    kind: .addToQueueControl,
                    score: 92,
                    label: Self.bestLabel(for: node, fallback: "Ajout à Automix potentiel"),
                    reasons: ["contrôle accessible", "action d’ajout à la file détectée"]
                ))
            }
        }

        let sorted = candidates.sorted {
            if $0.score == $1.score { return $0.nodePath < $1.nodePath }
            return $0.score > $1.score
        }
        let containerScore = sorted.first(where: { $0.kind == .automixContainer })?.score ?? 0
        let rowScore = sorted.first(where: { $0.kind == .queueRow })?.score ?? 0
        let controlScore = sorted.first(where: {
            $0.kind == .automixControl || $0.kind == .addToQueueControl
        })?.score ?? 0
        let confidence = min(100, Int(Double(containerScore + rowScore + controlScore) / 3.0))

        let summary: String
        if sorted.isEmpty {
            summary = "Aucun élément Automix suffisamment identifiable. Une capture sur le Mac cible est nécessaire."
        } else if containerScore >= 80 && (rowScore >= 65 || controlScore >= 80) {
            summary = "Des éléments Automix cohérents sont visibles en lecture seule. Toute action reste soumise à validation sur l’appareil."
        } else {
            summary = "Des candidats partiels ont été trouvés, mais l’arbre Accessibilité ne suffit pas encore pour automatiser la file."
        }

        return DjayAutomixReadinessReport(
            totalNodeCount: nodes.count,
            candidates: sorted,
            confidence: confidence,
            validationStatus: .requiresDeviceValidation,
            summary: summary
        )
    }

    private static func bestLabel(for node: DjayAccessibilityNode, fallback: String) -> String {
        node.visibleStrings.first ?? fallback
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .replacingOccurrences(of: "’", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .joined(separator: " ")
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains(normalize($0)) }
    }
}
