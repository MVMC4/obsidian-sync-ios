import Foundation

struct RecoveryScenario: Equatable, Identifiable {
    enum Kind: String {
        case peerOffline, wrongFolderID, staleVaultAccess, sessionTimeout,
             conflicts, localNetwork, notConfigured
    }
    let id: Kind
    let title: String
    let steps: [String]
}

struct RecoveryContext: Equatable {
    var phase: SyncSessionPhase
    var peerConnected: Bool
    var vaultSelected: Bool
    var profileConfigured: Bool
    var conflictCount: Int
    var lastError: String?
}

enum RecoveryGuidance {
    static func scenarios(for context: RecoveryContext) -> [RecoveryScenario] {
        var result: [RecoveryScenario] = []
        if !context.vaultSelected || !context.profileConfigured {
            result.append(.init(
                id: .notConfigured,
                title: "Finish setup first",
                steps: [
                    "Choose your Obsidian vault from the Files picker.",
                    "Pair the computer by entering or scanning its device ID and folder ID.",
                ]
            ))
        }
        if context.phase == .waitingForPeer || (!context.peerConnected && context.phase.isActive) {
            result.append(.init(
                id: .peerOffline,
                title: "Computer looks offline",
                steps: [
                    "Confirm Syncthing is running and the computer is awake on the same network.",
                    "Check the Local Network permission for Vault Sync in iPad Settings.",
                    "If discovery is blocked, set an explicit tcp:// address in pairing.",
                ]
            ))
        }
        if let error = context.lastError,
           error.localizedCaseInsensitiveContains("folder") {
            result.append(.init(
                id: .wrongFolderID,
                title: "Folder ID mismatch",
                steps: [
                    "Open Syncthing on the computer and copy the exact folder ID of the vault.",
                    "Edit pairing in Vault Sync and paste it without extra spaces.",
                ]
            ))
        }
        if context.phase == .failed,
           let error = context.lastError,
           error.localizedCaseInsensitiveContains("access") {
            result.append(.init(
                id: .staleVaultAccess,
                title: "Vault permission expired",
                steps: [
                    "In Settings, run the vault access test to confirm the saved permission.",
                    "If it fails, change the vault and re-select the folder in Files.",
                ]
            ))
        }
        if context.phase == .failed,
           let error = context.lastError,
           error.localizedCaseInsensitiveContains("timed out") {
            result.append(.init(
                id: .sessionTimeout,
                title: "Session timed out",
                steps: [
                    "Keep the app in the foreground for the whole session.",
                    "Make sure the computer finished scanning before you stop the session.",
                ]
            ))
        }
        if context.conflictCount > 0 {
            result.append(.init(
                id: .conflicts,
                title: "Conflict copies to review",
                steps: [
                    "Open the listed .sync-conflict files in Obsidian.",
                    "Keep the version you want and delete the copies once merged.",
                ]
            ))
        }
        return result
    }
}
