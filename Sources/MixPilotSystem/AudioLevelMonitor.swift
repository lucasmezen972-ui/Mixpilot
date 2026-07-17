#if os(macOS)
@preconcurrency import AVFoundation
import Foundation
import MixPilotCore

public enum AudioLevelMonitorError: Error, LocalizedError {
    case noInputChannels
    case alreadyRunning
    case engineStartFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noInputChannels:
            "La source audio sélectionnée ne fournit aucun canal d'entrée."
        case .alreadyRunning:
            "La surveillance audio est déjà active."
        case .engineStartFailed(let message):
            "Impossible de démarrer la surveillance audio : \(message)"
        }
    }
}

public final class AudioLevelMonitor: @unchecked Sendable {
    public typealias SampleHandler = @MainActor @Sendable (AudioLevelSample) -> Void

    private let engine = AVAudioEngine()
    private let stateLock = NSRecursiveLock()
    private let recoveryQueue = DispatchQueue(label: "com.mixpilot.audio-monitor.recovery")

    private var handler: SampleHandler?
    private var tapInstalled = false
    private var running = false
    private var wantsRunning = false
    private var recoveryScheduled = false
    private var bufferSize: AVAudioFrameCount = 1_024
    private var generation: UInt64 = 0
    private var recoveryPolicy = BoundedBackoffPolicy(
        limit: 4,
        firstDelay: 0.25,
        maximumDelay: 4
    )
    private var configurationObserver: NSObjectProtocol?

    public init() {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.configurationDidChange()
        }
    }

    public func start(bufferSize: AVAudioFrameCount = 1_024, handler: @escaping SampleHandler) throws {
        stateLock.lock()
        guard !wantsRunning else {
            stateLock.unlock()
            throw AudioLevelMonitorError.alreadyRunning
        }

        wantsRunning = true
        recoveryScheduled = true
        self.bufferSize = bufferSize
        self.handler = handler
        recoveryPolicy.reset()
        generation &+= 1
        let currentGeneration = generation

        do {
            try installTapAndStartLocked(generation: currentGeneration)
            running = true
            recoveryScheduled = false
            stateLock.unlock()
        } catch {
            cleanupEngineLocked()
            wantsRunning = false
            recoveryScheduled = false
            self.handler = nil
            stateLock.unlock()

            if let monitorError = error as? AudioLevelMonitorError {
                throw monitorError
            }
            throw AudioLevelMonitorError.engineStartFailed(error.localizedDescription)
        }
    }

    public func stop() {
        stateLock.lock()
        wantsRunning = false
        generation &+= 1
        recoveryScheduled = false
        recoveryPolicy.reset()
        cleanupEngineLocked()
        handler = nil
        stateLock.unlock()
    }

    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return running
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        stop()
    }

    private func configurationDidChange() {
        stateLock.lock()
        guard wantsRunning, !recoveryScheduled else {
            stateLock.unlock()
            return
        }

        generation &+= 1
        running = false
        recoveryScheduled = true
        let delay = recoveryPolicy.nextDelay()
        let currentHandler = handler
        if delay == nil {
            wantsRunning = false
            recoveryScheduled = false
            handler = nil
        }
        stateLock.unlock()

        deliverUnavailable(to: currentHandler)
        if let delay {
            scheduleRecovery(after: delay)
        }
    }

    private func scheduleRecovery(after delay: TimeInterval) {
        recoveryQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.recoverEngine()
        }
    }

    private func recoverEngine() {
        stateLock.lock()
        guard wantsRunning else {
            recoveryScheduled = false
            stateLock.unlock()
            return
        }

        cleanupEngineLocked()
        generation &+= 1
        let currentGeneration = generation

        do {
            try installTapAndStartLocked(generation: currentGeneration)
            running = true
            recoveryScheduled = false
            recoveryPolicy.reset()
            stateLock.unlock()
        } catch {
            running = false
            recoveryScheduled = false
            let delay = recoveryPolicy.nextDelay()
            let currentHandler = handler
            if delay != nil {
                recoveryScheduled = true
            } else {
                wantsRunning = false
                handler = nil
            }
            stateLock.unlock()

            deliverUnavailable(to: currentHandler)
            if let delay {
                scheduleRecovery(after: delay)
            }
        }
    }

    private func installTapAndStartLocked(generation: UInt64) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else {
            throw AudioLevelMonitorError.noInputChannels
        }

        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer, generation: generation)
        }
        tapInstalled = true

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            throw AudioLevelMonitorError.engineStartFailed(error.localizedDescription)
        }
    }

    private func cleanupEngineLocked() {
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
        }
        tapInstalled = false
        running = false
    }

    private func process(buffer: AVAudioPCMBuffer, generation: UInt64) {
        stateLock.lock()
        guard wantsRunning, running, generation == self.generation else {
            stateLock.unlock()
            return
        }
        let currentHandler = handler
        stateLock.unlock()

        guard let channels = buffer.floatChannelData else {
            deliverUnavailable(to: currentHandler)
            return
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return }

        var sumSquares = 0.0
        var peak = 0.0
        var sampleCount = 0

        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frameIndex in 0..<frameCount {
                let value = Double(channel[frameIndex])
                let absolute = abs(value)
                sumSquares += value * value
                peak = max(peak, absolute)
                sampleCount += 1
            }
        }

        let rms = sqrt(sumSquares / Double(max(1, sampleCount)))
        deliver(
            AudioLevelSample(
                timestamp: ProcessInfo.processInfo.systemUptime,
                rmsDB: Self.decibels(fromLinear: rms),
                peakDB: Self.decibels(fromLinear: peak),
                sourceAvailable: true
            ),
            to: currentHandler
        )
    }

    private func deliverUnavailable(to handler: SampleHandler?) {
        deliver(
            AudioLevelSample(
                timestamp: ProcessInfo.processInfo.systemUptime,
                rmsDB: -160,
                peakDB: -160,
                sourceAvailable: false
            ),
            to: handler
        )
    }

    private func deliver(_ sample: AudioLevelSample, to handler: SampleHandler?) {
        guard let handler else { return }
        Task { @MainActor in
            handler(sample)
        }
    }

    private static func decibels(fromLinear value: Double) -> Double {
        guard value > 0.000_000_01 else { return -160 }
        return max(-160, 20 * log10(value))
    }
}
#endif
