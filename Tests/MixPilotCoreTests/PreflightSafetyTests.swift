import Testing
@testable import MixPilotCore

@Test("Battery and missing local rescue remain warnings")
func optionalLocalSafetyDoesNotBlockLive() {
    var input = confirmedDirectInput()
    input.connectedToPower = false
    input.batteryLevel = 0.31
    input.emergencyAudioReady = false
    input.emergencyDuration = 0

    let report = PreflightEvaluator().evaluate(input)

    #expect(report.canStartLive)
    #expect(report.failedItems.isEmpty)
    #expect(report.items.first { $0.id == "power" }?.status == .warning)
    #expect(report.items.first { $0.id == "emergency" }?.status == .warning)
}

@Test("A closed DJ backend remains a critical failure")
func closedBackendBlocksLive() {
    var input = confirmedDirectInput()
    input.backendEnvironment?.isRunning = false

    let report = PreflightEvaluator().evaluate(input)

    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "backend-environment" }?.status == .failed)
}

@Test("A critical environment that was never tested blocks Live")
func untestedBackendEnvironmentBlocksLive() {
    var input = confirmedDirectInput()
    input.backendEnvironment = nil

    let report = PreflightEvaluator().evaluate(input)

    #expect(!report.canStartLive)
    #expect(report.items.first { $0.id == "backend-environment" }?.status == .notTested)
    #expect(report.failedItems.contains { $0.id == "backend-environment" })
}

@Test("Unavailable online services do not stop a local prepared Live")
func onlineServicesRemainOptional() {
    var input = confirmedDirectInput()
    input.internetAvailable = false
    input.onlineServicesAvailable = false

    let report = PreflightEvaluator().evaluate(input)

    #expect(report.canStartLive)
    #expect(report.items.first { $0.id == "internet" }?.status == .warning)
    #expect(report.items.first { $0.id == "online-services" }?.status == .warning)
}
