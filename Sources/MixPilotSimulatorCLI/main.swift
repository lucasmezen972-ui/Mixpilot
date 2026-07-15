import Foundation
import MixPilotCore

private struct CombinedSimulationReport: Codable {
    var stateMachine: SimulationReport
    var transitionRuntime: RuntimeStressReport
    var failureMatrix: FailureScenarioMatrixReport
    var succeeded: Bool
}

@main
struct MixPilotSimulatorCLI {
    static func main() async {
        let arguments = CommandLine.arguments
        let count = argumentValue("--tracks", in: arguments).flatMap(Int.init) ?? 50
        let injectFailures = arguments.contains("--inject-failures")
        let failures: [Int: IncidentKind] = injectFailures
            ? [
                8: .slowLoad,
                27: .wrongTrack,
                61: .internetLoss,
                93: .audioClipping,
                118: .audioSilence,
            ]
            : [:]

        do {
            let stateReport = try await SetSimulator().run(
                trackCount: count,
                injectedIncidents: failures
            )
            let runtimeReport = RuntimeStressSimulator().run(
                trackCount: count,
                framesPerSecond: 30
            )
            let failureMatrix = await FailureScenarioSuite().run(
                trackCount: min(max(12, count), 30)
            )
            let report = CombinedSimulationReport(
                stateMachine: stateReport,
                transitionRuntime: runtimeReport,
                failureMatrix: failureMatrix,
                succeeded: stateReport.succeeded && runtimeReport.succeeded && failureMatrix.succeeded
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            print(String(decoding: data, as: UTF8.self))
            if !report.succeeded { exit(1) }
        } catch {
            print("Simulation failed: \(error)")
            exit(2)
        }
    }

    private static func argumentValue(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
