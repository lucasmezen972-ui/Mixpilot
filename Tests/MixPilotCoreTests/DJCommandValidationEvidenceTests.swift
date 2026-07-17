import Testing
@testable import MixPilotCore

@Test("Only device-confirmed evidence permits Live control")
func onlyDeviceEvidencePermitsLiveControl() {
    let key = validationKey()

    let confirmed = DJCommandValidationRecord(
        key: key,
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )
    let automated = DJCommandValidationRecord(
        key: key,
        status: .automatedSuccess,
        evidence: .automatedProbe
    )
    let simulated = DJCommandValidationRecord(
        key: key,
        status: .automatedSuccess,
        evidence: .simulated
    )
    let rejected = DJCommandValidationRecord(
        key: key,
        status: .failed,
        evidence: .userRejected
    )

    #expect(confirmed.permitsLiveControl)
    #expect(!automated.permitsLiveControl)
    #expect(!simulated.permitsLiveControl)
    #expect(!rejected.permitsLiveControl)
}

@Test("Legacy device confirmations remain readable during migration")
func legacyDeviceConfirmationStillPermitsLiveControl() {
    let legacy = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        detail: "DEVICE_CONFIRMED"
    )
    let unrelatedLegacyDetail = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        detail: "AUTOMATED_SUCCESS"
    )

    #expect(legacy.permitsLiveControl)
    #expect(!unrelatedLegacyDetail.permitsLiveControl)
}

@Test("A typed non-device evidence cannot be upgraded by a legacy detail string")
func typedEvidenceTakesPriorityOverLegacyDetail() {
    let record = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        evidence: .simulated,
        detail: "DEVICE_CONFIRMED"
    )

    #expect(!record.permitsLiveControl)
}

private func validationKey() -> DJCommandValidationKey {
    DJCommandValidationKey(
        backend: .djay,
        softwareVersion: "test",
        controllerName: "MixPilot Virtual Controller",
        mappingVersion: "profile-1",
        action: .playA
    )
}
