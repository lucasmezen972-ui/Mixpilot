import Foundation
import MixPilotCore

private struct CombinedSimulationReport: Codable {
    var stateMachine: SimulationReport
    var transitionRuntime: RuntimeStressReport
    var failureMatrix: FailureScenarioMatrixReport
    var multiBackendMatrix: MultiBackendSimulationReport
    var validationStatus: DJValidationStatus
    var succeeded: Bool
}

@main
struct MixPilotSimulatorCLI {
    static func main() async {
        let arguments = CommandLine.arguments
        let count = argumentValue("--tracks", in: arguments).flatMap(Int.init) ?? 50
        let injectFailures = arguments.contains("--inject-failures")
        let selectedBackends = backends(from: argumentValue("--backend", in: arguments))
        let failures: [Int: IncidentKind] = injectFailures
            ? [
                8: .slowLoad,
                27: .wrongTrack,
                61: .internetLoss,
                93: .audioClipping,
                118: .audioSilence,
                151: .backendUnavailable,
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
            let multiBackendMatrix = MultiBackendSimulationSuite().run(
                backends: selectedBackends,
                trackCount: count
            )
            let succeeded = stateReport.succeeded &&
                runtimeReport.succeeded &&
                failureMatrix.succeeded &&
                multiBackendMatrix.succeeded

            let report = CombinedSimulationReport(
                stateMachine: stateReport,
                transitionRuntime: runtimeReport,
                failureMatrix: failureMatrix,
                multiBackendMatrix: multiBackendMatrix,
                validationStatus: .simulatedSuccess,
                succeeded: succeeded
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            print(String(decoding: data, as: UTF8.self))
            if !succeeded { exit(1) }
        } catch {
            print("Simulation failed: \(error)")
            exit(2)
        }
    }

    private static func argumentValue(
        _ name: String,
        in arguments: [String]
    ) -> String? {
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func backends(
        from argument: String?
    ) -> [DJBackendIdentifier] {
        guard let argument,
              argument.lowercased() != "all" else {
            return DJBackendIdentifier.allCases
        }
        if let backend = DJBackendIdentifier(rawValue: argument.lowercased()) {
            return [backend]
        }
        print("Unknown backend '\(argument)'. Expected djay, rekordbox, serato or all.")
        exit(64)
    }
}
