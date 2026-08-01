import XCTest
@testable import ObsidianSync

final class SyncthingBridgeTests: XCTestCase {
    @MainActor
    func testEmbeddedEngineCreatesIdentityStartsAndStops() throws {
        let bridge = SyncthingBridge()

        bridge.prepare()

        XCTAssertNil(bridge.lastError)
        XCTAssertFalse(bridge.deviceID?.isEmpty ?? true)
        XCTAssertEqual(bridge.state, "idle")

        try bridge.start()
        XCTAssertEqual(bridge.state, "running")

        try bridge.stop()
        XCTAssertEqual(bridge.state, "stopped")
    }
}
