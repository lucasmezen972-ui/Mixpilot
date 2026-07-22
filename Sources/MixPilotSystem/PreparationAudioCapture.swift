#if os(macOS)
@preconcurrency import AVFoundation
import Foundation
import MixPilotCore

public enum PreparationAudioCaptureError: Error, LocalizedError {
    case alreadyRunning
    case noInputChannels
    case startFailed(String)
    case noCapturedAudio

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning: "Une capture de préparation est déjà active."
        case .noInputChannels: "La source audio ne fournit aucun canal."
        case .startFailed(let message): "Impossible de démarrer la capture : \(message)"
        case .noCapturedAudio: "Aucun audio exploitable n'a été capturé."
        }
    }
}

// SAFETY: Every mutable capture field and AVAudioEngine lifecycle transition is serialized by lock; the audio tap calls append(), which uses the same lock.
public final class PreparationAudioCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var sampleRate = 44_100.0
    private var maximumSampleCount = 0
    private var running = false
    private var tapInstalled = false

    public init() {}

    public func start(maximumDuration: TimeInterval = 180) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !running else { throw PreparationAudioCaptureError.alreadyRunning }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw PreparationAudioCaptureError.noInputChannels }

        sampleRate = format.sampleRate
        maximumSampleCount = max(1, Int(maximumDuration * sampleRate))
        samples.removeAll(keepingCapacity: true)
        samples.reserveCapacity(min(maximumSampleCount, Int(sampleRate * 30)))

        input.installTap(onBus: 0, bufferSize: 2_048, format: format) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        tapInstalled = true

        do {
            engine.prepare()
            try engine.start()
            running = true
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            throw PreparationAudioCaptureError.startFailed(error.localizedDescription)
        }
    }

    public func stop() throws -> MonoPCMBuffer {
        lock.lock()
        if running {
            engine.stop()
            running = false
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        let captured = samples
        let capturedRate = sampleRate
        samples.removeAll(keepingCapacity: false)
        lock.unlock()

        guard !captured.isEmpty else { throw PreparationAudioCaptureError.noCapturedAudio }
        return MonoPCMBuffer(samples: captured, sampleRate: capturedRate)
    }

    public func cancel() {
        lock.lock()
        if running {
            engine.stop()
            running = false
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        samples.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    public func stopAndAnalyze(
        analyzer: LocalAudioAnalyzer = LocalAudioAnalyzer()
    ) throws -> LocalAudioAnalysis {
        analyzer.analyze(try stop())
    }

    public var capturedDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Double(samples.count) / max(1, sampleRate)
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    deinit {
        cancel()
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return }

        var mono = Array(repeating: Float.zero, count: frameCount)
        for channelIndex in 0..<channelCount {
            let channel = channels[channelIndex]
            for frameIndex in 0..<frameCount {
                mono[frameIndex] += channel[frameIndex] / Float(channelCount)
            }
        }

        lock.lock()
        let remaining = max(0, maximumSampleCount - samples.count)
        if remaining > 0 {
            samples.append(contentsOf: mono.prefix(remaining))
        }
        lock.unlock()
    }
}
#endif
