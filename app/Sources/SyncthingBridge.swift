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
final class SyncthingBridge: ObservableObject {
    @Published private(set) var deviceID: String?
    @Published private(set) var state = "idle"
    @Published private(set) var lastError: String?

    private var client: MobilecoreClient?

    func prepare() {
        guard client == nil else { return }

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
        }
    }

    func start() throws {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        try client.start()
        state = client.state()
    }

    func stop() throws {
        guard let client else {
            throw SyncthingBridgeError.clientNotPrepared
        }
        try client.stop()
        state = client.state()
    }
}
