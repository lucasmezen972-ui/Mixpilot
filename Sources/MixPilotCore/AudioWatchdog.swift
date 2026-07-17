import Foundation

public struct AudioLevelSample: Codable, Hashable, Sendable {
    public var timestamp: TimeInterval
    public var rmsDB: Double
    public var peakDB: Double
    public var sourceAvailable: Bool
    public init(timestamp: TimeInterval, rmsDB: Double, peakDB: Double, sourceAvailable: Bool = true) {
        self.timestamp = timestamp
        self.rmsDB = rmsDB
        self.peakDB = peakDB
        self.sourceAvailable = sourceAvailable
    }
}

public struct AudioWatchdogConfiguration: Codable, Hashable, Sendable {
    public var silenceThresholdDB: Double
    public var warningSilenceDuration: TimeInterval
    public var criticalSilenceDuration: TimeInterval
    public var clippingThresholdDB: Double
    public var clippingSampleCount: Int
    public init(silenceThresholdDB: Double = -48, warningSilenceDuration: TimeInterval = 0.8, criticalSilenceDuration: TimeInterval = 2, clippingThresholdDB: Double = -0.2, clippingSampleCount: Int = 3) {
        self.silenceThresholdDB = silenceThresholdDB
        self.warningSilenceDuration = max(0, warningSilenceDuration)
        self.criticalSilenceDuration = max(warningSilenceDuration, criticalSilenceDuration)
        self.clippingThresholdDB = clippingThresholdDB
        self.clippingSampleCount = max(1, clippingSampleCount)
    }
}

public enum AudioWatchdogEvent: Hashable, Sendable {
    case healthy(rmsDB: Double)
    case silenceWarning(duration: TimeInterval)
    case criticalSilence(duration: TimeInterval)
    case clipping(peakDB: Double)
    case sourceUnavailable
    case sourceRestored
}

public actor AudioWatchdog {
    private let configuration: AudioWatchdogConfiguration
    private var silenceStartedAt: TimeInterval?
    private var clippingSamples = 0
    private var sourceWasAvailable = true
    private var warningSilenceReported = false
    private var criticalSilenceReported = false
    private var clippingReported = false
    private var healthyRecoveryPending = false

    public init(configuration: AudioWatchdogConfiguration = AudioWatchdogConfiguration()) {
        self.configuration = configuration
    }

    public func reset() {
        silenceStartedAt = nil
        clippingSamples = 0
        sourceWasAvailable = true
        warningSilenceReported = false
        criticalSilenceReported = false
        clippingReported = false
        healthyRecoveryPending = false
    }

    public func ingest(_ sample: AudioLevelSample) -> AudioWatchdogEvent? {
        guard sample.sourceAvailable else {
            silenceStartedAt = nil
            clippingSamples = 0
            warningSilenceReported = false
            criticalSilenceReported = false
            clippingReported = false
            healthyRecoveryPending = false
            guard sourceWasAvailable else { return nil }
            sourceWasAvailable = false
            return .sourceUnavailable
        }
        if !sourceWasAvailable {
            sourceWasAvailable = true
            healthyRecoveryPending = true
            return .sourceRestored
        }
        if sample.peakDB >= configuration.clippingThresholdDB {
            clippingSamples += 1
            if clippingSamples >= configuration.clippingSampleCount && !clippingReported {
                clippingReported = true
                return .clipping(peakDB: sample.peakDB)
            }
        } else {
            clippingSamples = 0
            if clippingReported {
                clippingReported = false
                healthyRecoveryPending = true
            }
        }
        if sample.rmsDB <= configuration.silenceThresholdDB {
            if silenceStartedAt == nil { silenceStartedAt = sample.timestamp }
            let duration = max(0, sample.timestamp - (silenceStartedAt ?? sample.timestamp))
            if duration >= configuration.criticalSilenceDuration && !criticalSilenceReported {
                warningSilenceReported = true
                criticalSilenceReported = true
                return .criticalSilence(duration: duration)
            }
            if duration >= configuration.warningSilenceDuration && !warningSilenceReported {
                warningSilenceReported = true
                return .silenceWarning(duration: duration)
            }
            return nil
        }
        let recovered = silenceStartedAt != nil || warningSilenceReported || criticalSilenceReported
        silenceStartedAt = nil
        warningSilenceReported = false
        criticalSilenceReported = false
        if recovered || healthyRecoveryPending {
            healthyRecoveryPending = false
            return .healthy(rmsDB: sample.rmsDB)
        }
        return nil
    }

    public var hasReportedCriticalSilence: Bool { criticalSilenceReported }
}
