import Foundation
import XCTest
@testable import ObsidianSync

final class DiagnosticsTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func testEventStoreRoundTripsAndKeepsNewestEntries() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticEventStore(directory: directory, maximumEvents: 2)
        let events = [
            DiagnosticEvent(
                timestamp: Date(timeIntervalSince1970: 1),
                phase: "startingEngine",
                outcome: nil,
                status: nil
            ),
            DiagnosticEvent(
                timestamp: Date(timeIntervalSince1970: 2),
                phase: "synchronizing",
                outcome: nil,
                status: nil
            ),
            DiagnosticEvent(
                timestamp: Date(timeIntervalSince1970: 3),
                phase: "complete",
                outcome: .success,
                status: nil
            ),
        ]

        try store.save(events)

        XCTAssertEqual(try store.load(), Array(events.suffix(2)))
    }

    func testReportIncludesUsefulStateWithoutSensitiveConfiguration() throws {
        let profile = SyncProfile(
            peerDeviceID: "PEER-SECRET-ID",
            peerName: "Personal Laptop",
            addresses: ["tcp://192.0.2.10:22000"],
            folderID: "private-vault-id",
            folderLabel: "Private Notes"
        )
        let status = FolderSyncStatus(
            schemaVersion: 1,
            folderID: "private-vault-id",
            folderState: "syncing",
            stateChangedAt: "2026-08-01T00:00:00Z",
            peerConnected: true,
            localCompletionPct: 75,
            remoteCompletionPct: 80,
            globalBytes: 1_000,
            needBytes: 250,
            needItems: 2,
            needDeletes: 1,
            remoteNeedBytes: 200,
            remoteNeedItems: 3,
            remoteNeedDeletes: 0,
            upToDate: false
        )
        let data = try DiagnosticsReportBuilder.makeData(
            profile: profile,
            vaultSelected: true,
            engineState: "/private/var/mobile/secret",
            phase: .synchronizing,
            status: status,
            conflictCount: 4,
            events: [
                DiagnosticEvent(
                    timestamp: Date(timeIntervalSince1970: 1),
                    phase: "/private/var/mobile/event-leak",
                    outcome: .engineFailure,
                    status: DiagnosticStatusSummary(status: status)
                ),
            ],
            environment: DiagnosticsEnvironment(
                appVersion: "0.1.0",
                appBuild: "1",
                operatingSystem: "iPadOS 18.5",
                deviceClass: "iPad"
            ),
            generatedAt: Date(timeIntervalSince1970: 1_754_006_400)
        )
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(text.contains("\"addressMode\" : \"custom\""))
        XCTAssertTrue(text.contains("\"needItems\" : 2"))
        XCTAssertTrue(text.contains("\"conflictCount\" : 4"))
        XCTAssertTrue(text.contains("\"engineState\" : \"unknown\""))
        XCTAssertFalse(text.contains("PEER-SECRET-ID"))
        XCTAssertFalse(text.contains("Personal Laptop"))
        XCTAssertFalse(text.contains("192.0.2.10"))
        XCTAssertFalse(text.contains("private-vault-id"))
        XCTAssertFalse(text.contains("Private Notes"))
        XCTAssertFalse(text.contains("/private/var/mobile/secret"))
        XCTAssertFalse(text.contains("/private/var/mobile/event-leak"))
    }

    @MainActor
    func testRecorderPersistsOnlyStructuredEvents() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiagnosticEventStore(directory: directory)
        let recorder = DiagnosticsRecorder(
            store: store,
            now: { Date(timeIntervalSince1970: 42) }
        )

        recorder.record(phase: .waitingForPeer, status: nil, outcome: nil)
        recorder.record(phase: .failed, status: nil, outcome: .timeout)

        XCTAssertEqual(recorder.events.count, 2)
        XCTAssertEqual(recorder.events.last?.outcome, .timeout)
        XCTAssertEqual(try store.load(), recorder.events)
    }

    func testExportWriterProducesExpectedJSONFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = Data("{\"schemaVersion\":1}".utf8)

        let url = try DiagnosticsExportWriter(directory: directory).write(data)

        XCTAssertEqual(url.lastPathComponent, "vault-sync-diagnostics.json")
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
}
