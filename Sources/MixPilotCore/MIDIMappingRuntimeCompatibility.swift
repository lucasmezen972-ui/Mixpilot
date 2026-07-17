import Foundation

public extension DJControlAction {
    var requiresContinuousMIDIValue: Bool {
        switch self {
        case .crossfader,
             .volumeA, .volumeB,
             .lowEQA, .lowEQB,
             .midEQA, .midEQB,
             .highEQA, .highEQB,
             .filterA, .filterB,
             .pitchA, .pitchB,
             .echoAmountA, .echoAmountB:
            true
        default:
            false
        }
    }
}

public extension MIDIMessageMapping {
    func isRuntimeCompatible(with action: DJControlAction) -> Bool {
        if action.requiresContinuousMIDIValue {
            return kind == .controlChange
        }
        switch kind {
        case .note:
            return true
        case .controlChange:
            return isMomentary
        }
    }
}

public extension MIDIMappingProfile {
    func hasRuntimeCompatibleMapping(for action: DJControlAction) -> Bool {
        guard let mapping = self[action] else { return false }
        return mapping.isRuntimeCompatible(with: action)
    }
}
