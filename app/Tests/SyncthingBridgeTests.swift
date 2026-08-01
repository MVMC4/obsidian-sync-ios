import XCTest
@testable import ObsidianSync

final class SyncthingBridgeTests: XCTestCase {
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
