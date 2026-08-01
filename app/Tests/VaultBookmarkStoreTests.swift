import Foundation
import XCTest
@testable import ObsidianSync

final class VaultBookmarkStoreTests: XCTestCase {
    func testRecordRoundTripAndClear() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = VaultBookmarkStore(directory: directory)
        let record = VaultBookmarkRecord(
            bookmarkData: Data([0x01, 0x02, 0x03]),
            displayName: "Disposable Vault",
            selectedAt: Date(timeIntervalSince1970: 123)
        )

        XCTAssertNil(try store.load())
        try store.save(record)
        XCTAssertEqual(try store.load(), record)

        try store.clear()
        XCTAssertNil(try store.load())
    }

    func testRejectsUnknownSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = """
        {"schemaVersion":99,"bookmarkData":"AQID","displayName":"Vault","selectedAt":0}
        """.data(using: .utf8)!
        try encoded.write(to: directory.appendingPathComponent("vault-bookmark.json"))

        XCTAssertThrowsError(try VaultBookmarkStore(directory: directory).load())
    }
}
