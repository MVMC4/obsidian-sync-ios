import XCTest
@testable import ObsidianSync

final class SyncthingBridgeTests: XCTestCase {
    @MainActor
    func testDeviceIDNormalizationUsesSyncthingChecksums() throws {
        let bridge = SyncthingBridge()
        let canonical = "AIR6LPZ-7K4PTTV-UXQSMUU-CPQ5YWH-OEDFIIQ-JUG777G-2YQXXR5-YD6AWQR"

        XCTAssertEqual(
            try bridge.normalizeDeviceID("  \(canonical.lowercased())  "),
            canonical
        )
        XCTAssertThrowsError(try bridge.normalizeDeviceID("not-a-device-id"))
    }

    @MainActor
    func testEmbeddedEngineCreatesIdentityStartsAndStops() throws {
        let bridge = SyncthingBridge()

        try bridge.prepare()

        XCTAssertNil(bridge.lastError)
        XCTAssertFalse(bridge.deviceID?.isEmpty ?? true)
        XCTAssertEqual(bridge.state, "idle")

        try bridge.start()
        XCTAssertEqual(bridge.state, "running")

        try bridge.stop()
        XCTAssertEqual(bridge.state, "stopped")

        let originalDeviceID = bridge.deviceID
        try bridge.start()
        XCTAssertEqual(bridge.state, "running")
        XCTAssertEqual(bridge.deviceID, originalDeviceID)

        try bridge.stop()
        XCTAssertEqual(bridge.state, "stopped")
    }
}
