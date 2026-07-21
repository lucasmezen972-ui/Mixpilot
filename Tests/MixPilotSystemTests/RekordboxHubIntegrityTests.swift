import Foundation
import XCTest

final class RekordboxHubIntegrityTests: XCTestCase {
    func testHubKeepsAsyncFileIsolationAndPreparationPreview() throws {
        let source = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("Sources/MixPilotApp/RekordboxHubView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("private actor RekordboxHubFileStore"))
        XCTAssertTrue(source.contains("private let fileStore = RekordboxHubFileStore()"))
        XCTAssertEqual(
            source.components(separatedBy: "Task { @MainActor [weak self, fileStore] in").count - 1,
            2
        )
        XCTAssertTrue(source.contains("var preparationPreview: SetProject?"))
        XCTAssertTrue(source.contains("SetPreparationEngine().prepare("))
    }

    private func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
