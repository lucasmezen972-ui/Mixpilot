import Foundation
import XCTest

final class CloudLegacyCompatibilityTests: XCTestCase {
    func testLegacyAdapterMatchesCurrentCloudContracts() throws {
        let service = try sourceFile("Sources/MixPilotSystem/MixPilotCloudService.swift")
        let legacy = try sourceFile("Sources/MixPilotSystem/MixPilotCloudService+LegacyCompatibility.swift")

        XCTAssertFalse(service.contains("loadOrCreate().instanceID"))
        XCTAssertTrue(service.contains("MixPilotCloudAgentIdentityStore().loadOrCreate()"))
        XCTAssertFalse(legacy.contains("MixPilotCloudContext"))
        XCTAssertTrue(legacy.contains("async throws -> UUID"))
        XCTAssertTrue(legacy.contains("capabilities: DJBackendCapabilities()"))
        XCTAssertTrue(legacy.contains(
            "validationStatus: DJValidationStatus.requiresBackendValidation.rawValue"
        ))
    }

    private func sourceFile(_ path: String) throws -> String {
        try String(
            contentsOf: repositoryRoot().appendingPathComponent(path),
            encoding: .utf8
        )
    }

    private func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
