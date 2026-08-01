import Foundation
import XCTest
@testable import ObsidianSync

final class VaultSpikeRunnerTests: XCTestCase {
    func testRunCompletesEveryOperationAndCleansUp() throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }

        let report = try VaultSpikeRunner().run(in: vault)

        XCTAssertEqual(report.completedOperations, ["create", "read", "edit", "rename", "delete"])
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: vault.appendingPathComponent(".vault-sync-access-test").path
            )
        )
    }
}
