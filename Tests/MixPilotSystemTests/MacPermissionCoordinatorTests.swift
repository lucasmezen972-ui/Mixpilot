#if os(macOS)
import Testing
@testable import MixPilotSystem

@Test("permission snapshot exposes degraded mode without hiding missing access")
func permissionSnapshotDegradedMode() {
    let snapshot = MacPermissionSnapshot(
        accessibility: .authorized,
        screenRecording: .actionRequired,
        microphone: .denied
    )

    #expect(!snapshot.allRecommendedGranted)
    #expect(snapshot.missingPermissions == [.screenRecording, .microphone])
    #expect(snapshot[.accessibility].isAuthorized)
    #expect(!snapshot[.microphone].isAuthorized)
}

@Test("permission snapshot is ready only when every recommended access is granted")
func permissionSnapshotReady() {
    let snapshot = MacPermissionSnapshot(
        accessibility: .authorized,
        screenRecording: .authorized,
        microphone: .authorized
    )

    #expect(snapshot.allRecommendedGranted)
    #expect(snapshot.missingPermissions.isEmpty)
}
#endif
