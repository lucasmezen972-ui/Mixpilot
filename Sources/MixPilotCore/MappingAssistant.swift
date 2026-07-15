import Foundation

public enum MappingActionGroup: String, Codable, CaseIterable, Sendable {
    case transport = "Transport"
    case browser = "Bibliothèque"
    case mixer = "Mixeur"
    case equalizer = "Égalisation"
    case performance = "Effets et boucles"
}

public extension SeratoAction {
    var displayName: String {
        switch self {
        case .playA: "Lecture Deck A"
        case .playB: "Lecture Deck B"
        case .pauseA: "Pause Deck A"
        case .pauseB: "Pause Deck B"
        case .cueA: "Cue Deck A"
        case .cueB: "Cue Deck B"
        case .syncA: "Sync Deck A"
        case .syncB: "Sync Deck B"
        case .loadA: "Charger sur Deck A"
        case .loadB: "Charger sur Deck B"
        case .browserUp: "Bibliothèque : monter"
        case .browserDown: "Bibliothèque : descendre"
        case .browserFocus: "Bibliothèque : focus"
        case .volumeA: "Volume Deck A"
        case .volumeB: "Volume Deck B"
        case .crossfader: "Crossfader"
        case .lowEQA: "Basses Deck A"
        case .lowEQB: "Basses Deck B"
        case .midEQA: "Médiums Deck A"
        case .midEQB: "Médiums Deck B"
        case .highEQA: "Aigus Deck A"
        case .highEQB: "Aigus Deck B"
        case .filterA: "Filtre Deck A"
        case .filterB: "Filtre Deck B"
        case .pitchA: "Pitch Deck A"
        case .pitchB: "Pitch Deck B"
        case .echoA: "Echo Deck A"
        case .echoB: "Echo Deck B"
        case .echoAmountA: "Quantité Echo Deck A"
        case .echoAmountB: "Quantité Echo Deck B"
        case .loopA: "Boucle Deck A"
        case .loopB: "Boucle Deck B"
        case .exitLoopA: "Sortie boucle Deck A"
        case .exitLoopB: "Sortie boucle Deck B"
        }
    }

    var mappingGroup: MappingActionGroup {
        switch self {
        case .playA, .playB, .pauseA, .pauseB, .cueA, .cueB, .syncA, .syncB, .loadA, .loadB:
            .transport
        case .browserUp, .browserDown, .browserFocus:
            .browser
        case .volumeA, .volumeB, .crossfader, .pitchA, .pitchB:
            .mixer
        case .lowEQA, .lowEQB, .midEQA, .midEQB, .highEQA, .highEQB, .filterA, .filterB:
            .equalizer
        case .echoA, .echoB, .echoAmountA, .echoAmountB, .loopA, .loopB, .exitLoopA, .exitLoopB:
            .performance
        }
    }

    var isContinuousControl: Bool {
        switch self {
        case .volumeA, .volumeB, .crossfader,
             .lowEQA, .lowEQB, .midEQA, .midEQB,
             .highEQA, .highEQB, .filterA, .filterB,
             .pitchA, .pitchB, .echoAmountA, .echoAmountB:
            true
        default:
            false
        }
    }

    var mappingInstruction: String {
        isContinuousControl
            ? "Dans Serato, clique sur le contrôle « \(displayName) », puis clique sur Envoyer. Vérifie ensuite ses positions minimale, centrale et maximale."
            : "Dans Serato, clique sur la commande « \(displayName) », puis clique sur Envoyer pour associer le message MIDI."
    }
}

public struct MappingWizardStep: Identifiable, Codable, Hashable, Sendable {
    public var id: String { action.rawValue }
    public var action: SeratoAction
    public var mapping: MIDIMessageMapping
    public var tested: Bool
    public var testSucceeded: Bool?

    public init(
        action: SeratoAction,
        mapping: MIDIMessageMapping,
        tested: Bool = false,
        testSucceeded: Bool? = nil
    ) {
        self.action = action
        self.mapping = mapping
        self.tested = tested
        self.testSucceeded = testSucceeded
    }
}

public struct MappingWizardState: Codable, Hashable, Sendable {
    public var profile: MIDIMappingProfile
    public var steps: [MappingWizardStep]
    public var currentIndex: Int

    public init(
        profile: MIDIMappingProfile = .developmentDefault,
        actions: [SeratoAction] = SeratoAction.allCases,
        currentIndex: Int = 0
    ) {
        self.profile = profile
        self.steps = actions.compactMap { action in
            guard let mapping = profile[action] else { return nil }
            return MappingWizardStep(action: action, mapping: mapping)
        }
        self.currentIndex = min(max(0, currentIndex), max(0, steps.count - 1))
    }

    public var currentStep: MappingWizardStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    public var progress: Double {
        guard !steps.isEmpty else { return 1 }
        return Double(completedStepCount) / Double(steps.count)
    }

    public var completedStepCount: Int {
        steps.filter { $0.testSucceeded == true }.count
    }

    public var isComplete: Bool {
        !steps.isEmpty && completedStepCount == steps.count
    }

    public mutating func moveNext() {
        currentIndex = min(max(0, steps.count - 1), currentIndex + 1)
    }

    public mutating func movePrevious() {
        currentIndex = max(0, currentIndex - 1)
    }

    public mutating func jump(to action: SeratoAction) {
        guard let index = steps.firstIndex(where: { $0.action == action }) else { return }
        currentIndex = index
    }

    public mutating func updateCurrentMapping(_ mapping: MIDIMessageMapping) {
        guard steps.indices.contains(currentIndex) else { return }
        steps[currentIndex].mapping = mapping
        steps[currentIndex].tested = false
        steps[currentIndex].testSucceeded = nil
        profile[steps[currentIndex].action] = mapping
    }

    public mutating func recordCurrentTest(succeeded: Bool) {
        guard steps.indices.contains(currentIndex) else { return }
        steps[currentIndex].tested = true
        steps[currentIndex].testSucceeded = succeeded
        profile[steps[currentIndex].action] = steps[currentIndex].mapping
    }
}
