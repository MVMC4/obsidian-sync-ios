import Foundation
import XCTest
@testable import ObsidianSync

final class VaultConflictScannerTests: XCTestCase {
    func testFindsRelativeConflictPathsAndIgnoresNormalNotes() throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nested = vault.appendingPathComponent("Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }
        try Data("normal".utf8).write(to: nested.appendingPathComponent("normal.md"))
        try Data("conflict".utf8).write(
            to: nested.appendingPathComponent("idea.sync-conflict-20260801-120000-DEVICE.md")
        )

        let conflicts = try VaultConflictScanner().conflictPaths(in: vault)

        XCTAssertEqual(conflicts, ["Notes/idea.sync-conflict-20260801-120000-DEVICE.md"])
    }

    func testCapsDiagnosticResults() throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }
        for index in 0..<3 {
            try Data().write(to: vault.appendingPathComponent("n\(index).sync-conflict-test.md"))
        }

        XCTAssertEqual(try VaultConflictScanner(maximumResults: 2).conflictPaths(in: vault).count, 2)
    }
}
