import Foundation

struct SyncActivityItem: Codable, Equatable {
    let path: String
    let direction: String
    let action: String
    let itemType: String
    let result: String
    let completedAt: String

    var stableID: String {
        "\(completedAt)|\(direction)|\(path)|\(action)"
    }

    var fileName: String {
        (path as NSString).lastPathComponent
    }

    var parentPath: String {
        let parts = path.split(separator: "/")
        guard parts.count > 1 else { return "" }
        return parts.dropLast().joined(separator: "/")
    }

    var date: Date {
        SyncActivityItem.dateFormatter.date(from: completedAt) ?? .distantPast
    }

    var isIncoming: Bool { direction == "incoming" }
    var isFailed: Bool { result == "failed" }

    static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

struct SyncActivitySnapshot: Codable, Equatable {
    let schemaVersion: Int
    let folderID: String
    let items: [SyncActivityItem]
}

enum SyncActivityStore {
    static let currentSchemaVersion = 1
    static let maximumItems = 60

    static func url(in directory: URL) -> URL {
        directory.appendingPathComponent("recent-activity.json", isDirectory: false)
    }

    static func load(directory: URL, fileManager: FileManager = .default) -> [SyncActivityItem] {
        let url = self.url(in: directory)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schemaVersion == currentSchemaVersion
        else { return [] }
        return sanitize(envelope.items)
    }

    static func save(_ items: [SyncActivityItem], directory: URL,
                     fileManager: FileManager = .default) {
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            let envelope = Envelope(
                schemaVersion: currentSchemaVersion,
                items: Array(sanitize(items).prefix(maximumItems))
            )
            let data = try JSONEncoder().encode(envelope)
            try data.write(to: url(in: directory),
                           options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // Activity persistence must never affect a sync session.
        }
    }

    static func merge(session: [SyncActivityItem], persisted: [SyncActivityItem],
                      cap: Int = maximumItems) -> [SyncActivityItem] {
        var seen = Set<String>()
        var combined: [SyncActivityItem] = []
        for item in sanitize(session) + sanitize(persisted) {
            if seen.insert(item.stableID).inserted {
                combined.append(item)
            }
        }
        combined.sort { $0.date > $1.date }
        return Array(combined.prefix(cap))
    }

    static func sanitize(_ items: [SyncActivityItem]) -> [SyncActivityItem] {
        items.filter { isSafeRelativePath($0.path) }
    }

    static func isSafeRelativePath(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("\\") { return false }
        if trimmed.contains(":") { return false }
        if trimmed == ".." || trimmed.hasPrefix("../") || trimmed.contains("/../") { return false }
        return true
    }

    private struct Envelope: Codable {
        let schemaVersion: Int
        let items: [SyncActivityItem]
    }
}
