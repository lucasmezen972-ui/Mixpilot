#if os(macOS)
import Foundation
import MixPilotCore

@MainActor
final class MappingAssistantSession: ObservableObject {
    @Published private(set) var state: MappingWizardState
    @Published private(set) var status = "Prêt à commencer"

    private let defaults: UserDefaults
    private let storageKey = "MixPilotMappingConfirmationsV1"

    init(profile: MIDIMappingProfile, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var initial = MappingWizardState(profile: profile)
        let confirmations = defaults.dictionary(forKey: storageKey) as? [String: Bool] ?? [:]
        for index in initial.steps.indices {
            if let value = confirmations[initial.steps[index].action.rawValue] {
                initial.currentIndex = index
                initial.recordCurrentTest(succeeded: value)
            }
        }
        initial.currentIndex = initial.steps.firstIndex(where: { $0.testSucceeded != true }) ?? 0
        state = initial
        refreshStatus()
    }

    var currentStep: MappingWizardStep? { state.currentStep }
    var progress: Double { state.progress }
    var completedCount: Int { state.completedStepCount }
    var totalCount: Int { state.steps.count }

    func moveNext() {
        state.moveNext()
        refreshStatus()
    }

    func movePrevious() {
        state.movePrevious()
        refreshStatus()
    }

    func jump(to action: SeratoAction) {
        state.jump(to: action)
        refreshStatus()
    }

    func record(succeeded: Bool) {
        state.recordCurrentTest(succeeded: succeeded)
        persist()
        refreshStatus()
    }

    func reset(profile: MIDIMappingProfile) {
        defaults.removeObject(forKey: storageKey)
        state = MappingWizardState(profile: profile)
        refreshStatus()
    }

    private func persist() {
        var confirmations: [String: Bool] = [:]
        for step in state.steps {
            guard let succeeded = step.testSucceeded else { continue }
            confirmations[step.action.rawValue] = succeeded
        }
        defaults.set(confirmations, forKey: storageKey)
    }

    private func refreshStatus() {
        if state.isComplete {
            status = "Toutes les commandes ont été confirmées"
        } else {
            status = "Étape \(state.currentIndex + 1) sur \(max(1, state.steps.count))"
        }
    }
}
#endif
