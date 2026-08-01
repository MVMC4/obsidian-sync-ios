import XCTest
@testable import ObsidianSync

final class RecoveryGuidanceTests: XCTestCase {
    func testNotConfiguredWhenMissingVaultOrProfile() {
        let scenarios = RecoveryGuidance.scenarios(for: RecoveryContext(
            phase: .idle, peerConnected: false, vaultSelected: false,
            profileConfigured: false, conflictCount: 0, lastError: nil
        ))
        XCTAssertTrue(scenarios.contains { $0.id == .notConfigured })
    }

    func testPeerOfflineDuringWaitAndConflictsSurface() {
        let scenarios = RecoveryGuidance.scenarios(for: RecoveryContext(
            phase: .waitingForPeer, peerConnected: false, vaultSelected: true,
            profileConfigured: true, conflictCount: 2, lastError: nil
        ))
        XCTAssertTrue(scenarios.contains { $0.id == .peerOffline })
        XCTAssertTrue(scenarios.contains { $0.id == .conflicts })
    }

    func testWrongFolderAndStaleAccessFromErrorText() {
        let folder = RecoveryGuidance.scenarios(for: RecoveryContext(
            phase: .failed, peerConnected: true, vaultSelected: true,
            profileConfigured: true, conflictCount: 0,
            lastError: "folder is not configured"
        ))
        XCTAssertTrue(folder.contains { $0.id == .wrongFolderID })
        let access = RecoveryGuidance.scenarios(for: RecoveryContext(
            phase: .failed, peerConnected: true, vaultSelected: true,
            profileConfigured: true, conflictCount: 0,
            lastError: "vault access denied"
        ))
        XCTAssertTrue(access.contains { $0.id == .staleVaultAccess })
    }

    func testFailedUnreachablePeerStillShowsOfflineRecovery() {
        let scenarios = RecoveryGuidance.scenarios(for: RecoveryContext(
            phase: .failed, peerConnected: false, vaultSelected: true,
            profileConfigured: true, conflictCount: 0,
            lastError: SyncSessionError.peerUnavailable.localizedDescription
        ))

        XCTAssertTrue(scenarios.contains { $0.id == .peerOffline })
    }
}
