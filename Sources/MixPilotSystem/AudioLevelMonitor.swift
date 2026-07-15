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
    private let stateLock = NSLock()
    private var handler: SampleHandler?
    private var tapInstalled = false
    private var running = false

    public init() {}

    public func start(bufferSize: AVAudioFrameCount = 1_024, handler: @escaping SampleHandler) throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !running else { throw AudioLevelMonitorError.alreadyRunning }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw AudioLevelMonitorError.noInputChannels }

        self.handler = handler
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        tapInstalled = true

        do {
            engine.prepare()
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            self.handler = nil
            throw AudioLevelMonitorError.engineStartFailed(error.localizedDescription)
        }
    }

    public func stop() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard running || tapInstalled else { return }
        engine.stop()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
        }
        tapInstalled = false
        running = false
        handler = nil
    }

    public var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return running
    }

    deinit {
        stop()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else {
            deliver(AudioLevelSample(
                timestamp: ProcessInfo.processInfo.systemUptime,
                rmsDB: -160,
                peakDB: -160,
                sourceAvailable: false
            ))
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
        deliver(AudioLevelSample(
            timestamp: ProcessInfo.processInfo.systemUptime,
            rmsDB: Self.decibels(fromLinear: rms),
            peakDB: Self.decibels(fromLinear: peak),
            sourceAvailable: true
        ))
    }

    private func deliver(_ sample: AudioLevelSample) {
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
