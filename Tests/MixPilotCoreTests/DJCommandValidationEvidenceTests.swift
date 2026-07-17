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

@Test("Live evidence requires software, controller and mapping identities")
func liveEvidenceRequiresFullyQualifiedContext() {
    let missingSoftware = DJCommandValidationRecord(
        key: validationKey(softwareVersion: nil),
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )
    let missingController = DJCommandValidationRecord(
        key: validationKey(controllerName: nil),
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )
    let missingMapping = DJCommandValidationRecord(
        key: validationKey(mappingVersion: nil),
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )
    let blankSoftware = DJCommandValidationRecord(
        key: validationKey(softwareVersion: "  "),
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )

    #expect(!missingSoftware.permitsLiveControl)
    #expect(!missingController.permitsLiveControl)
    #expect(!missingMapping.permitsLiveControl)
    #expect(!blankSoftware.permitsLiveControl)
}

@Test("Legacy device confirmations remain readable only with complete context")
func legacyDeviceConfirmationStillPermitsLiveControl() {
    let legacy = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        detail: "DEVICE_CONFIRMED"
    )
    let incompleteLegacy = DJCommandValidationRecord(
        key: validationKey(softwareVersion: nil),
        status: .automatedSuccess,
        detail: "DEVICE_CONFIRMED"
    )
    let unrelatedLegacyDetail = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        detail: "AUTOMATED_SUCCESS"
    )

    #expect(legacy.permitsLiveControl)
    #expect(!incompleteLegacy.permitsLiveControl)
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

private func validationKey(
    softwareVersion: String? = "test",
    controllerName: String? = "MixPilot Virtual Controller",
    mappingVersion: String? = "profile-1"
) -> DJCommandValidationKey {
    DJCommandValidationKey(
        backend: .djay,
        softwareVersion: softwareVersion,
        controllerName: controllerName,
        mappingVersion: mappingVersion,
        action: .playA
    )
}
