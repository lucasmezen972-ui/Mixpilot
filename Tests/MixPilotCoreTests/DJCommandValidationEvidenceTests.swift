import Foundation
import Testing
@testable import MixPilotCore

private let validationContext = DJValidationPlatformContext(
    operatingSystemVersion: "macOS 26.0",
    hardwareModel: "MacTest1,1",
    appBuild: "300"
)

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

    #expect(confirmed.permitsLiveControl(in: validationContext))
    #expect(!automated.permitsLiveControl(in: validationContext))
    #expect(!simulated.permitsLiveControl(in: validationContext))
    #expect(!rejected.permitsLiveControl(in: validationContext))
}

@Test("Live evidence requires software, controller, mapping and platform identities")
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
    let missingHardware = DJCommandValidationRecord(
        key: validationKey(platformContext: DJValidationPlatformContext(
            operatingSystemVersion: "macOS 26.0",
            hardwareModel: nil,
            appBuild: "300"
        )),
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )

    #expect(!missingSoftware.permitsLiveControl(in: validationContext))
    #expect(!missingController.permitsLiveControl(in: validationContext))
    #expect(!missingMapping.permitsLiveControl(in: validationContext))
    #expect(!missingHardware.permitsLiveControl(in: validationContext))
}

@Test("Evidence is rejected after the platform context changes")
func evidenceIsRejectedAfterPlatformChange() {
    let record = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        evidence: .deviceConfirmed
    )

    let newOS = DJValidationPlatformContext(
        operatingSystemVersion: "macOS 26.1",
        hardwareModel: "MacTest1,1",
        appBuild: "300"
    )
    let newHardware = DJValidationPlatformContext(
        operatingSystemVersion: "macOS 26.0",
        hardwareModel: "MacTest2,1",
        appBuild: "300"
    )
    let newBuild = DJValidationPlatformContext(
        operatingSystemVersion: "macOS 26.0",
        hardwareModel: "MacTest1,1",
        appBuild: "301"
    )

    #expect(!record.permitsLiveControl(in: newOS))
    #expect(!record.permitsLiveControl(in: newHardware))
    #expect(!record.permitsLiveControl(in: newBuild))
}

@Test("Legacy confirmation without platform fields remains readable but cannot permit Live")
func legacyConfirmationWithoutPlatformContextIsRejected() throws {
    let legacyJSON = """
    {
      "key": {
        "backend": "djay",
        "softwareVersion": "test",
        "controllerName": "MixPilot Virtual Controller",
        "mappingVersion": "profile-1",
        "action": "playA"
      },
      "status": "AUTOMATED_SUCCESS",
      "validatedAt": 0,
      "detail": "DEVICE_CONFIRMED"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970

    let legacy = try decoder.decode(
        DJCommandValidationRecord.self,
        from: Data(legacyJSON.utf8)
    )

    #expect(!legacy.permitsLiveControl(in: validationContext))
    #expect(!legacy.key.isFullyQualifiedForLive)
}

@Test("A typed non-device evidence cannot be upgraded by a legacy detail string")
func typedEvidenceTakesPriorityOverLegacyDetail() {
    let record = DJCommandValidationRecord(
        key: validationKey(),
        status: .automatedSuccess,
        evidence: .simulated,
        detail: "DEVICE_CONFIRMED"
    )

    #expect(!record.permitsLiveControl(in: validationContext))
}

private func validationKey(
    softwareVersion: String? = "test",
    controllerName: String? = "MixPilot Virtual Controller",
    mappingVersion: String? = "profile-1",
    platformContext: DJValidationPlatformContext = validationContext
) -> DJCommandValidationKey {
    DJCommandValidationKey(
        backend: .djay,
        softwareVersion: softwareVersion,
        controllerName: controllerName,
        mappingVersion: mappingVersion,
        action: .playA,
        platformContext: platformContext
    )
}
