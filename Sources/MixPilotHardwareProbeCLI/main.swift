#if os(macOS)
import Foundation
import MixPilotMIDI
import MixPilotSystem

private struct HardwareProbeReport: Codable {
    var generatedAt: Date
    var seratoRunning: Bool
    var seratoProcessIdentifier: Int32?
    var accessibilityGranted: Bool
    var audioPermission: String
    var seratoWindowTitle: String?
    var visibleTextCount: Int
    var libraryRowCount: Int
    var virtualMIDIPortCreated: Bool
    var audioMonitorStarted: Bool
    var audioSampleCount: Int
    var connectedToPower: Bool
    var batteryLevel: Double?
    var failures: [String]

    var succeeded: Bool { failures.isEmpty }
}

@main
@MainActor
struct MixPilotHardwareProbeCLI {
    static func main() async {
        let strict = CommandLine.arguments.contains("--strict")
        var failures: [String] = []

        let environment = SeratoEnvironmentProbe().probe()
        if strict && !environment.isRunning { failures.append("Serato DJ Pro n'est pas lancé") }
        if strict && !environment.accessibilityGranted { failures.append("Accessibilité non autorisée") }

        let bridge = SeratoAccessibilityBridge()
        let observation = bridge.observe(maxDepth: 6, maximumStrings: 500)
        let rows = bridge.libraryRows(maxRows: 1_000)
        if strict && rows.isEmpty { failures.append("Aucune ligne de bibliothèque Serato accessible") }

        var midiCreated = false
        do {
            _ = try CoreMIDIController()
            midiCreated = true
        } catch {
            failures.append("Port MIDI virtuel : \(error.localizedDescription)")
        }

        let audioMonitor = AudioLevelMonitor()
        var audioSamples = 0
        var audioStarted = false
        do {
            try audioMonitor.start { _ in audioSamples += 1 }
            audioStarted = true
            try? await Task.sleep(for: .seconds(1.2))
            audioMonitor.stop()
            if strict && audioSamples == 0 { failures.append("Aucun échantillon de niveau audio reçu") }
        } catch {
            failures.append("Surveillance audio : \(error.localizedDescription)")
        }

        let power = PowerStatusProbe().read()
        if strict && !power.connectedToPower {
            failures.append("Le Mac n'est pas branché au secteur")
        }

        let report = HardwareProbeReport(
            generatedAt: Date(),
            seratoRunning: environment.isRunning,
            seratoProcessIdentifier: environment.processIdentifier,
            accessibilityGranted: environment.accessibilityGranted,
            audioPermission: environment.audioPermission,
            seratoWindowTitle: observation.windowTitle,
            visibleTextCount: observation.visibleText.count,
            libraryRowCount: rows.count,
            virtualMIDIPortCreated: midiCreated,
            audioMonitorStarted: audioStarted,
            audioSampleCount: audioSamples,
            connectedToPower: power.connectedToPower,
            batteryLevel: power.batteryLevel,
            failures: failures
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        } catch {
            print("{\"encodingError\":\"\(error.localizedDescription)\"}")
            exit(2)
        }

        if strict && !report.succeeded { exit(1) }
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
