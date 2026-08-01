import Foundation
import XCTest
@testable import ObsidianSync

final class SyncProfileStoreTests: XCTestCase {
    func testValidationNormalizesDefaults() throws {
        let profile = try SyncProfile(
            peerDeviceID: "  DEVICE-ID  ",
            peerName: " ",
            addresses: [],
            folderID: " vault-id ",
            folderLabel: " "
        ).validated()

        XCTAssertEqual(profile.peerDeviceID, "DEVICE-ID")
        XCTAssertEqual(profile.peerName, "Syncthing peer")
        XCTAssertEqual(profile.addresses, ["dynamic"])
        XCTAssertEqual(profile.folderID, "vault-id")
        XCTAssertEqual(profile.folderLabel, "vault-id")
    }

    func testRoundTripAndClear() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SyncProfileStore(directory: directory)
        let profile = SyncProfile(
            peerDeviceID: "DEVICE-ID",
            peerName: "Desktop",
            addresses: ["dynamic"],
            folderID: "vault-id",
            folderLabel: "Notes",
            updatedAt: Date(timeIntervalSince1970: 123)
        )

        XCTAssertNil(try store.load())
        try store.save(profile)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.peerDeviceID, profile.peerDeviceID)
        XCTAssertEqual(loaded.folderID, profile.folderID)

        try store.clear()
        XCTAssertNil(try store.load())
    }
}
