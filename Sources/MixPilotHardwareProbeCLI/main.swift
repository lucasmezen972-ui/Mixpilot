#if os(macOS)
import Foundation
import MixPilotCore
import MixPilotMIDI
import MixPilotSystem

private struct HardwareProbeReport: Codable {
    var generatedAt: Date
    var backend: DJBackendIdentifier
    var backendDisplayName: String
    var softwareVersion: String?
    var softwareRunning: Bool
    var processIdentifier: Int32?
    var accessibilityGranted: Bool
    var windowTitle: String?
    var visibleTextCount: Int
    var visibleText: [String]?
    var libraryRowCount: Int
    var virtualMIDIPortCreated: Bool
    var midiPublication: MIDIPublicationDiagnostic?
    var audioMonitorStarted: Bool
    var audioSampleCount: Int
    var connectedToPower: Bool
    var batteryLevel: Double?
    var warnings: [String]
    var failures: [String]

    var succeeded: Bool { failures.isEmpty }
}

// SAFETY: Access to value is serialized by lock; no mutable state escapes.
private final class AudioSampleCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func read() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

@main
@MainActor
struct MixPilotHardwareProbeCLI {
    static func main() async {
        guard let backend = selectedBackend() else {
            print("Usage: MixPilotHardwareProbeCLI --backend djay|rekordbox|serato [--strict]")
            exit(2)
        }

        let strict = CommandLine.arguments.contains("--strict")
        var warnings: [String] = []
        var failures: [String] = []

        let environment = DJApplicationEnvironmentDetector().detect(backend)
        if strict && !environment.isRunning {
            failures.append("\(backend.displayName) n’est pas lancé")
        }

        let bridge = DJAccessibilityBridge()
        let observation = bridge.observe(
            backend: backend,
            maxDepth: 6,
            maximumStrings: 500
        )
        let rows = await bridge.libraryRows(backend: backend, maxRows: 1_000)
        if strict && !observation.accessibilityGranted {
            failures.append("L’autorisation Accessibilité n’est pas accordée")
        }
        if rows.isEmpty {
            warnings.append("Aucune ligne de bibliothèque visible ; utilise une playlist de test ou l’import documenté du backend")
        }

        var midiCreated = false
        var midiPublication: MIDIPublicationDiagnostic?
        do {
            let controller = try CoreMIDIController()
            let diagnostic = controller.publicationDiagnostic()
            midiPublication = diagnostic
            midiCreated = diagnostic.sourcePublished
            if strict && backend != .djay && !diagnostic.sourcePublished {
                failures.append("Le contrôleur MIDI virtuel n’est pas publié")
            }
        } catch {
            let message = "Le contrôleur MIDI virtuel n’a pas pu être créé"
            if strict && backend != .djay {
                failures.append(message)
            } else {
                warnings.append(message)
            }
        }

        let sampleCounter = AudioSampleCounter()
        let audioMonitor = AudioLevelMonitor()
        var audioStarted = false
        do {
            try audioMonitor.start { _ in sampleCounter.increment() }
            audioStarted = true
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                audioMonitor.stop()
                warnings.append("Le test audio a été interrompu avant la fin de la fenêtre d’observation")
            }
            audioMonitor.stop()
            if strict && sampleCounter.read() == 0 {
                failures.append("Aucun niveau audio n’a été observé")
            }
        } catch {
            failures.append("La surveillance audio n’a pas pu démarrer")
        }

        let power = PowerStatusProbe().read()
        if strict && !power.connectedToPower {
            failures.append("Le Mac n’est pas branché au secteur")
        }

        let report = HardwareProbeReport(
            generatedAt: Date(),
            backend: backend,
            backendDisplayName: backend.displayName,
            softwareVersion: environment.softwareVersion,
            softwareRunning: environment.isRunning,
            processIdentifier: environment.processIdentifier,
            accessibilityGranted: observation.accessibilityGranted,
            windowTitle: observation.windowTitle,
            visibleTextCount: observation.visibleText.count,
            visibleText: CommandLine.arguments.contains("--include-visible-text")
                ? observation.visibleText
                : nil,
            libraryRowCount: rows.count,
            virtualMIDIPortCreated: midiCreated,
            midiPublication: midiPublication,
            audioMonitorStarted: audioStarted,
            audioSampleCount: sampleCounter.read(),
            connectedToPower: power.connectedToPower,
            batteryLevel: power.batteryLevel,
            warnings: warnings,
            failures: failures
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        } catch {
            print("{\"encodingError\":\"hardware_probe_report_failed\"}")
            exit(2)
        }

        if strict && !report.succeeded { exit(1) }
    }

    private static func selectedBackend() -> DJBackendIdentifier? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--backend"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return DJBackendIdentifier(rawValue: arguments[index + 1].lowercased())
    }
}
#else
@main
struct MixPilotHardwareProbeCLI {
    static func main() {
        print("MixPilotHardwareProbeCLI requires macOS")
    }
}
#endif
