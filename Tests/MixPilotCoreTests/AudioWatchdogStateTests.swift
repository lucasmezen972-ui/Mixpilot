import Testing
@testable import MixPilotCore

@Test("Silence events are edge triggered")
func silenceEventsAreEdgeTriggered() async {
    let watchdog = AudioWatchdog(configuration: AudioWatchdogConfiguration(
        silenceThresholdDB: -48,
        warningSilenceDuration: 1,
        criticalSilenceDuration: 2
    ))

    let first = await watchdog.ingest(sample(at: 0, rms: -80))
    let warning = await watchdog.ingest(sample(at: 1.1, rms: -80))
    let duplicateWarning = await watchdog.ingest(sample(at: 1.5, rms: -80))
    let critical = await watchdog.ingest(sample(at: 2.1, rms: -80))
    let duplicateCritical = await watchdog.ingest(sample(at: 3, rms: -80))
    let recovered = await watchdog.ingest(sample(at: 3.1, rms: -20))

    #expect(first == nil)
    #expect(warning == .silenceWarning(duration: 1.1))
    #expect(duplicateWarning == nil)
    #expect(critical == .criticalSilence(duration: 2.1))
    #expect(duplicateCritical == nil)
    #expect(recovered == .healthy(rmsDB: -20))
}

@Test("Source availability events are edge triggered")
func sourceAvailabilityIsEdgeTriggered() async {
    let watchdog = AudioWatchdog()

    let lost = await watchdog.ingest(sample(at: 0, available: false))
    let duplicateLoss = await watchdog.ingest(sample(at: 1, available: false))
    let restored = await watchdog.ingest(sample(at: 2, rms: -20))
    let healthy = await watchdog.ingest(sample(at: 2.1, rms: -20))
    let stable = await watchdog.ingest(sample(at: 2.2, rms: -20))

    #expect(lost == .sourceUnavailable)
    #expect(duplicateLoss == nil)
    #expect(restored == .sourceRestored)
    #expect(healthy == .healthy(rmsDB: -20))
    #expect(stable == nil)
}

@Test("Clipping is emitted once per episode")
func clippingIsLatchedPerEpisode() async {
    let watchdog = AudioWatchdog(configuration: AudioWatchdogConfiguration(
        clippingThresholdDB: -1,
        clippingSampleCount: 2
    ))

    let first = await watchdog.ingest(sample(at: 0, rms: -10, peak: -0.5))
    let clipped = await watchdog.ingest(sample(at: 0.1, rms: -10, peak: -0.5))
    let duplicate = await watchdog.ingest(sample(at: 0.2, rms: -10, peak: -0.5))
    let recovered = await watchdog.ingest(sample(at: 0.3, rms: -10, peak: -3))
    let newFirst = await watchdog.ingest(sample(at: 0.4, rms: -10, peak: -0.5))
    let clippedAgain = await watchdog.ingest(sample(at: 0.5, rms: -10, peak: -0.5))

    #expect(first == nil)
    #expect(clipped == .clipping(peakDB: -0.5))
    #expect(duplicate == nil)
    #expect(recovered == .healthy(rmsDB: -10))
    #expect(newFirst == nil)
    #expect(clippedAgain == .clipping(peakDB: -0.5))
}

@Test("Reset clears watchdog state")
func resetClearsWatchdogState() async {
    let watchdog = AudioWatchdog(configuration: AudioWatchdogConfiguration(
        warningSilenceDuration: 0,
        criticalSilenceDuration: 0
    ))

    _ = await watchdog.ingest(sample(at: 0, rms: -80))
    let reportedBeforeReset = await watchdog.hasReportedCriticalSilence
    await watchdog.reset()
    let reportedAfterReset = await watchdog.hasReportedCriticalSilence
    let eventAfterReset = await watchdog.ingest(sample(at: 1, rms: -80))

    #expect(reportedBeforeReset)
    #expect(!reportedAfterReset)
    #expect(eventAfterReset == .criticalSilence(duration: 0))
}

private func sample(
    at timestamp: TimeInterval,
    rms: Double = -160,
    peak: Double = -20,
    available: Bool = true
) -> AudioLevelSample {
    AudioLevelSample(
        timestamp: timestamp,
        rmsDB: rms,
        peakDB: peak,
        sourceAvailable: available
    )
}
