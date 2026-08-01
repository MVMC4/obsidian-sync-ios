import Foundation
import XCTest
@testable import ObsidianSync

@MainActor
private final class FakeSyncEngine: SyncEngineControlling {
    var deviceID: String? = "LOCAL-ID"
    var state = "idle"
    var lastError: String?
    var statuses: [FolderSyncStatus] = []
    var activitySnapshots: [SyncActivitySnapshot] = []
    var calls: [String] = []
    var configureError: Error?

    func prepare() throws { calls.append("prepare") }
    func start() throws { calls.append("start"); state = "running" }
    func configurePeer(_ profile: SyncProfile) throws {
        calls.append("configurePeer")
        if let configureError { throw configureError }
    }
    func configureFolder(_ profile: SyncProfile, vaultPath: String) throws {
        calls.append("configureFolder:\(vaultPath)")
    }
    func scan(folderID: String) throws { calls.append("scan") }
    func folderStatus(folderID: String, peerDeviceID: String) throws -> FolderSyncStatus {
        calls.append("status")
        return statuses.isEmpty ? Self.status(connected: false) : statuses.removeFirst()
    }
    func recentActivity(folderID: String) throws -> SyncActivitySnapshot {
        calls.append("activity")
        if !activitySnapshots.isEmpty { return activitySnapshots.removeFirst() }
        return SyncActivitySnapshot(schemaVersion: 1, folderID: folderID, items: [])
    }
    func stop() throws { calls.append("stop"); state = "stopped" }

    static func status(connected: Bool, state: String = "idle", upToDate: Bool = false) -> FolderSyncStatus {
        FolderSyncStatus(
            schemaVersion: 1, folderID: "vault-id", folderState: state,
            stateChangedAt: "2026-08-01T00:00:00Z", peerConnected: connected,
            localCompletionPct: upToDate ? 100 : 50, remoteCompletionPct: upToDate ? 100 : 50,
            globalBytes: 100, needBytes: upToDate ? 0 : 50, needItems: upToDate ? 0 : 1,
            needDeletes: 0, remoteNeedBytes: upToDate ? 0 : 50, remoteNeedItems: upToDate ? 0 : 1,
            remoteNeedDeletes: 0, upToDate: upToDate
        )
    }
}

private final class FakeVaultSession: VaultAccessSessionProtocol {
    let url = URL(fileURLWithPath: "/tmp/disposable-vault", isDirectory: true)
    private(set) var closeCalls = 0
    func close() { closeCalls += 1 }
}

private struct FakeConflictScanner: VaultConflictScanning {
    var paths: [String] = []
    func conflictPaths(in vaultURL: URL) throws -> [String] { paths }
}

@MainActor
private final class FakeDiagnosticsRecorder: DiagnosticsRecording {
    private(set) var events: [DiagnosticEvent] = []
    func record(phase: SyncSessionPhase, status: FolderSyncStatus?, outcome: DiagnosticOutcome?) {
        events.append(DiagnosticEvent(timestamp: Date(timeIntervalSince1970: 0),
                                      phase: phase.rawValue, outcome: outcome,
                                      status: status.map(DiagnosticStatusSummary.init)))
    }
}

@MainActor
private final class FakeVaultAccess: VaultAccessProviding {
    let session = FakeVaultSession()
    func openSession() throws -> any VaultAccessSessionProtocol { session }
}

final class SyncSessionControllerTests: XCTestCase {
    private let profile = SyncProfile(
        peerDeviceID: "PEER-ID", peerName: "Desktop",
        folderID: "vault-id", folderLabel: "Notes"
    )

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @MainActor
    func testSuccessfulSessionPollsActivityPersistsAndCleansUp() async {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let engine = FakeSyncEngine()
        engine.statuses = [
            FakeSyncEngine.status(connected: false),
            FakeSyncEngine.status(connected: true, state: "syncing"),
            FakeSyncEngine.status(connected: true, upToDate: true),
            FakeSyncEngine.status(connected: true, upToDate: true),
        ]
        let item = SyncActivityItem(path: "Notes/a.md", direction: "incoming", action: "updated",
                                    itemType: "file", result: "completed",
                                    completedAt: "2026-08-01T12:00:00.0Z")
        engine.activitySnapshots = [
            SyncActivitySnapshot(schemaVersion: 1, folderID: "vault-id", items: []),
            SyncActivitySnapshot(schemaVersion: 1, folderID: "vault-id", items: [item]),
            SyncActivitySnapshot(schemaVersion: 1, folderID: "vault-id", items: [item]),
            SyncActivitySnapshot(schemaVersion: 1, folderID: "vault-id", items: [item]),
        ]
        let vault = FakeVaultAccess()
        let diagnostics = FakeDiagnosticsRecorder()
        let controller = SyncSessionController(
            engine: engine, vaultAccess: vault,
            policy: SyncSessionPolicy(maximumPolls: 4, pollIntervalNanoseconds: 0, requiredStableSamples: 2),
            conflictScanner: FakeConflictScanner(), diagnostics: diagnostics,
            activityDirectory: dir, sleeper: { _ in }
        )
        await controller.run(profile: profile)
        XCTAssertEqual(controller.phase, .complete)
        XCTAssertEqual(engine.calls.last, "stop")
        XCTAssertEqual(vault.session.closeCalls, 1)
        XCTAssertEqual(controller.activity.map(\.path), ["Notes/a.md"])
        XCTAssertTrue(engine.calls.contains("activity"))
        XCTAssertEqual(SyncActivityStore.load(directory: dir).map(\.path), ["Notes/a.md"])
    }

    @MainActor
    func testConfigurationFailureStopsEngineAndReleasesVault() async {
        struct TestError: LocalizedError { var errorDescription: String? { "Invalid peer" } }
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let engine = FakeSyncEngine(); engine.configureError = TestError()
        let vault = FakeVaultAccess()
        let diagnostics = FakeDiagnosticsRecorder()
        let controller = SyncSessionController(
            engine: engine, vaultAccess: vault, conflictScanner: FakeConflictScanner(),
            diagnostics: diagnostics, activityDirectory: dir, sleeper: { _ in }
        )
        await controller.run(profile: profile)
        XCTAssertEqual(controller.phase, .failed)
        XCTAssertEqual(controller.lastError, "Invalid peer")
        XCTAssertEqual(engine.calls.last, "stop")
        XCTAssertEqual(vault.session.closeCalls, 1)
        XCTAssertEqual(diagnostics.events.last?.outcome, .configurationFailure)
    }

    @MainActor
    func testTimeoutDoesNotClaimCompletion() async {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let engine = FakeSyncEngine()
        engine.statuses = [FakeSyncEngine.status(connected: false)]
        let vault = FakeVaultAccess()
        let controller = SyncSessionController(
            engine: engine, vaultAccess: vault,
            policy: SyncSessionPolicy(maximumPolls: 1, pollIntervalNanoseconds: 0, requiredStableSamples: 2),
            conflictScanner: FakeConflictScanner(), activityDirectory: dir, sleeper: { _ in }
        )
        await controller.run(profile: profile)
        XCTAssertEqual(controller.phase, .failed)
        XCTAssertEqual(controller.lastError, SyncSessionError.timedOut.localizedDescription)
        XCTAssertEqual(vault.session.closeCalls, 1)
    }

    @MainActor
    func testConflictCopiesProduceAttentionState() async {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let engine = FakeSyncEngine()
        engine.statuses = [
            FakeSyncEngine.status(connected: true, upToDate: true),
            FakeSyncEngine.status(connected: true, upToDate: true),
        ]
        let vault = FakeVaultAccess()
        let controller = SyncSessionController(
            engine: engine, vaultAccess: vault,
            policy: SyncSessionPolicy(maximumPolls: 2, pollIntervalNanoseconds: 0, requiredStableSamples: 2),
            conflictScanner: FakeConflictScanner(paths: ["Notes/idea.sync-conflict-20260801.md"]),
            activityDirectory: dir, sleeper: { _ in }
        )
        await controller.run(profile: profile)
        XCTAssertEqual(controller.phase, .completeWithConflicts)
        XCTAssertEqual(controller.conflicts, ["Notes/idea.sync-conflict-20260801.md"])
        XCTAssertEqual(vault.session.closeCalls, 1)
    }
}
