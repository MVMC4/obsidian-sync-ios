import Combine
import Foundation
@preconcurrency import Mobilecore

enum SyncthingBridgeError: LocalizedError {
    case clientCreationFailed
    case clientNotPrepared

    var errorDescription: String? {
        switch self {
        case .clientCreationFailed:
            return "The embedded Syncthing client could not be created."
        case .clientNotPrepared:
            return "Prepare the embedded Syncthing client before starting it."
        }
    }
}

@MainActor
protocol SyncEngineControlling: AnyObject {
    var deviceID: String? { get }
    var state: String { get }
    var lastError: String? { get }

    func prepare() throws
    func start() throws
    func configurePeer(_ profile: SyncProfile) throws
    func configureFolder(_ profile: SyncProfile, vaultPath: String) throws
    func scan(folderID: String) throws
    func folderStatus(folderID: String, peerDeviceID: String) throws -> FolderSyncStatus
    func stop() throws
}

struct FolderSyncStatus: Codable, Equatable {
    let schemaVersion: Int
    let folderID: String
    let folderState: String
    let stateChangedAt: String
    let peerConnected: Bool
    let localCompletionPct: Double
    let remoteCompletionPct: Double
    let globalBytes: Int64
    let needBytes: Int64
    let needItems: Int
    let needDeletes: Int
    let remoteNeedBytes: Int64
    let remoteNeedItems: Int
    let remoteNeedDeletes: Int
    let upToDate: Bool
}

@MainActor
final class SyncthingBridge: ObservableObject, SyncEngineControlling {
    @Published private(set) var deviceID: String?
    @Published private(set) var state = "idle"
    @Published private(set) var lastError: String?

    private var client: MobilecoreClient?

    func prepare() throws {
        if client != nil, state != "stopped", state != "failed" {
            return
        }

        client = nil

        do {
            let stateDirectory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
                .appendingPathComponent("VaultSync", isDirectory: true)
                .appendingPathComponent("Engine", isDirectory: true)
            try FileManager.default.createDirectory(
                at: stateDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )

            var creationError: NSError?
            guard let newClient = MobilecoreNewClient(stateDirectory.path, &creationError) else {
                throw creationError ?? SyncthingBridgeError.clientCreationFailed
            }
            client = newClient
            deviceID = newClient.deviceID()
            state = newClient.state()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func start() throws {
        try prepare()
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        try client.start()
        state = client.state()
    }

    func configurePeer(_ profile: SyncProfile) throws {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        let addressesData = try JSONEncoder().encode(profile.addresses)
        guard let addressesJSON = String(data: addressesData, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try client.configurePeer(
            profile.peerDeviceID,
            name: profile.peerName,
            addressesJSON: addressesJSON
        )
    }

    func configureFolder(_ profile: SyncProfile, vaultPath: String) throws {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        try client.configureFolder(
            profile.folderID,
            folderPath: vaultPath,
            label: profile.folderLabel,
            peerDeviceID: profile.peerDeviceID
        )
    }

    func scan(folderID: String) throws {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        try client.scan(folderID)
    }

    func folderStatus(folderID: String, peerDeviceID: String) throws -> FolderSyncStatus {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        var statusError: NSError?
        let json = client.folderStatusJSON(
            folderID,
            peerDeviceID: peerDeviceID,
            error: &statusError
        )
        if let statusError {
            throw statusError
        }
        return try JSONDecoder().decode(FolderSyncStatus.self, from: Data(json.utf8))
    }

    func stop() throws {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        try client.stop()
        state = client.state()
    }

    nonisolated func normalizeDeviceID(_ value: String) throws -> String {
        var normalizationError: NSError?
        let normalized = MobilecoreNormalizeDeviceID(value, &normalizationError)
        if let normalizationError {
            throw normalizationError
        }
        return normalized
    }
}
