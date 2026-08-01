import Foundation

struct SyncProfile: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var peerDeviceID: String
    var peerName: String
    var addresses: [String]
    var folderID: String
    var folderLabel: String
    var updatedAt: Date

    init(
        peerDeviceID: String,
        peerName: String,
        addresses: [String] = ["dynamic"],
        folderID: String,
        folderLabel: String,
        updatedAt: Date = Date()
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.peerDeviceID = peerDeviceID
        self.peerName = peerName
        self.addresses = addresses
        self.folderID = folderID
        self.folderLabel = folderLabel
        self.updatedAt = updatedAt
    }

    func validated() throws -> SyncProfile {
        var copy = self
        copy.peerDeviceID = peerDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.peerName = peerName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.folderID = folderID.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.folderLabel = folderLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.addresses = addresses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !copy.peerDeviceID.isEmpty else {
            throw SyncProfileError.missingPeerDeviceID
        }
        guard !copy.folderID.isEmpty else {
            throw SyncProfileError.missingFolderID
        }
        if copy.peerName.isEmpty {
            copy.peerName = "Syncthing peer"
        }
        if copy.folderLabel.isEmpty {
            copy.folderLabel = copy.folderID
        }
        if copy.addresses.isEmpty {
            copy.addresses = ["dynamic"]
        }
        copy.updatedAt = Date()
        return copy
    }
}

enum SyncProfileError: LocalizedError {
    case missingPeerDeviceID
    case missingFolderID
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .missingPeerDeviceID:
            return "Enter the Syncthing device ID of an existing computer."
        case .missingFolderID:
            return "Enter the Syncthing folder ID used by the existing vault."
        case let .unsupportedSchema(version):
            return "The saved sync profile uses unsupported schema version \(version)."
        }
    }
}

struct SyncProfileStore {
    private let directory: URL
    private let fileManager: FileManager

    init(
        directory: URL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("VaultSync", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    var profileURL: URL {
        directory.appendingPathComponent("sync-profile.json", isDirectory: false)
    }

    func load() throws -> SyncProfile? {
        guard fileManager.fileExists(atPath: profileURL.path) else {
            return nil
        }
        let profile = try JSONDecoder().decode(SyncProfile.self, from: Data(contentsOf: profileURL))
        guard profile.schemaVersion == SyncProfile.currentSchemaVersion else {
            throw SyncProfileError.unsupportedSchema(profile.schemaVersion)
        }
        return profile
    }

    func save(_ profile: SyncProfile) throws {
        let validated = try profile.validated()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let data = try JSONEncoder().encode(validated)
        try data.write(to: profileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: profileURL.path) else { return }
        try fileManager.removeItem(at: profileURL)
    }
}
