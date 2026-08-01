import Foundation

struct VaultBookmarkRecord: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let bookmarkData: Data
    let displayName: String
    let selectedAt: Date

    init(bookmarkData: Data, displayName: String, selectedAt: Date = Date()) {
        schemaVersion = Self.currentSchemaVersion
        self.bookmarkData = bookmarkData
        self.displayName = displayName
        self.selectedAt = selectedAt
    }
}

struct VaultBookmarkStore {
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

    var recordURL: URL {
        directory.appendingPathComponent("vault-bookmark.json", isDirectory: false)
    }

    func load() throws -> VaultBookmarkRecord? {
        guard fileManager.fileExists(atPath: recordURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: recordURL)
        let record = try JSONDecoder().decode(VaultBookmarkRecord.self, from: data)
        guard record.schemaVersion == VaultBookmarkRecord.currentSchemaVersion else {
            throw VaultAccessError.unsupportedBookmarkVersion(record.schemaVersion)
        }
        return record
    }

    func save(_ record: VaultBookmarkRecord) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        let data = try JSONEncoder().encode(record)
        try data.write(to: recordURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: recordURL.path) else {
            return
        }
        try fileManager.removeItem(at: recordURL)
    }
}
