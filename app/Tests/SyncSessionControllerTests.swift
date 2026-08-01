import Foundation
import XCTest
@testable import ObsidianSync

@MainActor
private final class FakeSyncEngine: SyncEngineControlling {
    var deviceID: String? = "LOCAL-ID"
    var state = "idle"
    var lastError: String?
    var statuses: [FolderSyncStatus] = []
    var calls: [String] = []
    var configureError: Error?

    func prepare() throws {
        calls.append("prepare")
    }

    func start() throws {
        calls.append("start")
        state = "running"
    }

    func configurePeer(_ profile: SyncProfile) throws {
        calls.append("configurePeer")
        if let configureError { throw configureError }
    }

    func configureFolder(_ profile: SyncProfile, vaultPath: String) throws {
        calls.append("configureFolder:\(vaultPath)")
    }

    func scan(folderID: String) throws {
        calls.append("scan")
    }

    func folderStatus(folderID: String, peerDeviceID: String) throws -> FolderSyncStatus {
        calls.append("status")
        return statuses.isEmpty ? Self.status(connected: false) : statuses.removeFirst()
    }

    func stop() throws {
        calls.append("stop")
        state = "stopped"
    }

    static func status(connected: Bool, state: String = "idle", upToDate: Bool = false) -> FolderSyncStatus {
        FolderSyncStatus(
            schemaVersion: 1,
            folderID: "vault-id",
            folderState: state,
            stateChangedAt: "2026-08-01T00:00:00Z",
            peerConnected: connected,
            localCompletionPct: upToDate ? 100 : 50,
            remoteCompletionPct: upToDate ? 100 : 50,
            globalBytes: 100,
            needBytes: upToDate ? 0 : 50,
            needItems: upToDate ? 0 : 1,
            needDeletes: 0,
            remoteNeedBytes: upToDate ? 0 : 50,
            remoteNeedItems: upToDate ? 0 : 1,
            remoteNeedDeletes: 0,
            upToDate: upToDate
        )
    }
}

private final class FakeVaultSession: VaultAccessSessionProtocol {
    let url = URL(fileURLWithPath: "/tmp/disposable-vault", isDirectory: true)
    private(set) var closeCalls = 0

    func close() {
        closeCalls += 1
    }
}

@MainActor
private final class FakeVaultAccess: VaultAccessProviding {
    let session = FakeVaultSession()

    func openSession() throws -> any VaultAccessSessionProtocol {
        session
    }
}

final class SyncSessionControllerTests: XCTestCase {
    private let profile = SyncProfile(
        peerDeviceID: "PEER-ID",
        peerName: "Desktop",
        folderID: "vault-id",
        folderLabel: "Notes"
    )

    @MainActor
    func testSuccessfulSessionRequiresTwoStableSamplesAndCleansUp() async {
        let engine = FakeSyncEngine()
        engine.statuses = [
            FakeSyncEngine.status(connected: false),
            FakeSyncEngine.status(connected: true, state: "syncing"),
            FakeSyncEngine.status(connected: true, upToDate: true),
            FakeSyncEngine.status(connected: true, upToDate: true),
        ]
        let vault = FakeVaultAccess()
        let controller = SyncSessionController(
            engine: engine,
            vaultAccess: vault,
            policy: SyncSessionPolicy(maximumPolls: 4, pollIntervalNanoseconds: 0, requiredStableSamples: 2),
            sleeper: { _ in }
        )

        await controller.run(profile: profile)

        XCTAssertEqual(controller.phase, .complete)
        XCTAssertEqual(engine.calls.last, "stop")
        XCTAssertEqual(engine.calls.filter { $0 == "status" }.count, 4)
        XCTAssertEqual(vault.session.closeCalls, 1)
    }

    @MainActor
    func testConfigurationFailureStopsEngineAndReleasesVault() async {
        struct TestError: LocalizedError {
            var errorDescription: String? { "Invalid peer" }
        }
        let engine = FakeSyncEngine()
        engine.configureError = TestError()
        let vault = FakeVaultAccess()
        let controller = SyncSessionController(
            engine: engine,
            vaultAccess: vault,
            sleeper: { _ in }
        )

        await controller.run(profile: profile)

        XCTAssertEqual(controller.phase, .failed)
        XCTAssertEqual(controller.lastError, "Invalid peer")
        XCTAssertEqual(engine.calls.last, "stop")
        XCTAssertEqual(vault.session.closeCalls, 1)
    }

    @MainActor
    func testTimeoutDoesNotClaimCompletion() async {
        let engine = FakeSyncEngine()
        engine.statuses = [FakeSyncEngine.status(connected: false)]
        let vault = FakeVaultAccess()
        let controller = SyncSessionController(
            engine: engine,
            vaultAccess: vault,
            policy: SyncSessionPolicy(maximumPolls: 1, pollIntervalNanoseconds: 0, requiredStableSamples: 2),
            sleeper: { _ in }
        )

        await controller.run(profile: profile)

        XCTAssertEqual(controller.phase, .failed)
        XCTAssertEqual(controller.lastError, SyncSessionError.timedOut.localizedDescription)
        XCTAssertEqual(vault.session.closeCalls, 1)
    }
}
