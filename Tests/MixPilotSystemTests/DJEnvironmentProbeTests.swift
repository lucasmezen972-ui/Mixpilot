#if os(macOS)
import Testing
@testable import MixPilotCore
@testable import MixPilotSystem

@Test("The environment probe keeps the requested backend explicit")
@MainActor
func environmentProbeUsesExplicitBackend() {
    let result = DJEnvironmentProbe(backend: .djay).probe()
    #expect(result.backend == .djay)
}

@Test("The deprecated Serato probe remains source-compatible without selecting a default backend")
@MainActor
func legacySeratoProbeIsExplicitlySerato() {
    let result = SeratoEnvironmentProbe().probe()
    #expect(result.backend == .serato)
}
#endif
