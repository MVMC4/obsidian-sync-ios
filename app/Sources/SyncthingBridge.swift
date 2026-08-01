import Combine
import Foundation
@preconcurrency import Mobilecore

enum SyncthingBridgeError: LocalizedError {
    case clientCreationFailed

    var errorDescription: String? {
        switch self {
        case .clientCreationFailed:
            return "The embedded Syncthing client could not be created."
        }
    }
}

@MainActor
final class SyncthingBridge: ObservableObject {
    @Published private(set) var deviceID: String?
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

            guard let newClient = try MobilecoreNewClient(stateDirectory.path) else {
                throw SyncthingBridgeError.clientCreationFailed
            }
            client = newClient
            deviceID = newClient.deviceID()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
