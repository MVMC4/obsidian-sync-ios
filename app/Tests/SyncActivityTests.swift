import Foundation
import XCTest
@testable import ObsidianSync

final class SyncActivityTests: XCTestCase {
    func testDecodesGoContractAndComputesStableIdentity() throws {
        let json = """
        {"schemaVersion":1,"folderID":"vault","items":[
          {"path":"Notes/a.md","direction":"outgoing","action":"updated",
           "itemType":"file","result":"detected","completedAt":"2026-08-01T12:00:01.5Z"},
          {"path":"Notes/b.md","direction":"incoming","action":"updated",
           "itemType":"file","result":"completed","completedAt":"2026-08-01T12:00:02.5Z"}
        ]}
        """
        let snap = try JSONDecoder().decode(SyncActivitySnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snap.schemaVersion, 1)
        XCTAssertEqual(snap.items.count, 2)
        XCTAssertEqual(snap.items[0].fileName, "a.md")
        XCTAssertEqual(snap.items[0].parentPath, "Notes")
        XCTAssertNotEqual(snap.items[0].stableID, snap.items[1].stableID)
        XCTAssertTrue(snap.items[1].isIncoming)
    }

    func testMergeDeduplicatesCapsAndSortsNewestFirst() {
        let older = SyncActivityItem(path: "a.md", direction: "outgoing", action: "updated",
                                     itemType: "file", result: "detected",
                                     completedAt: "2026-08-01T12:00:00.0Z")
        let newer = SyncActivityItem(path: "b.md", direction: "incoming", action: "updated",
                                     itemType: "file", result: "completed",
                                     completedAt: "2026-08-01T12:00:05.0Z")
        let merged = SyncActivityStore.merge(session: [older], persisted: [older, newer], cap: 10)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first?.path, "b.md")
    }

    func testMergeRejectsUnsafePathsFromPersistedState() {
        let bad = SyncActivityItem(path: "/etc/leak", direction: "incoming", action: "updated",
                                   itemType: "file", result: "completed",
                                   completedAt: "2026-08-01T12:00:00.0Z")
        let good = SyncActivityItem(path: "Notes/ok.md", direction: "incoming", action: "updated",
                                    itemType: "file", result: "completed",
                                    completedAt: "2026-08-01T12:00:01.0Z")
        let merged = SyncActivityStore.merge(session: [], persisted: [bad, good])
        XCTAssertEqual(merged.map(\.path), ["Notes/ok.md"])
        XCTAssertFalse(SyncActivityStore.isSafeRelativePath("C:/vault/x.md"))
        XCTAssertFalse(SyncActivityStore.isSafeRelativePath("../escape.md"))
    }

    func testStoreRoundTripsBoundedHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = (0..<5).map { i in
            SyncActivityItem(path: "n\(i).md", direction: "incoming", action: "updated",
                             itemType: "file", result: "completed",
                             completedAt: "2026-08-01T12:00:0\(i).0Z")
        }
        SyncActivityStore.save(items, directory: directory)
        XCTAssertEqual(SyncActivityStore.load(directory: directory).count, 5)
    }
}
