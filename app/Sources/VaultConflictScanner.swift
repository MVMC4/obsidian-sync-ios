import Foundation

protocol VaultConflictScanning {
    func conflictPaths(in vaultURL: URL) throws -> [String]
}

struct VaultConflictScanner: VaultConflictScanning {
    let maximumResults: Int
    private let fileManager: FileManager

    init(maximumResults: Int = 100, fileManager: FileManager = .default) {
        self.maximumResults = maximumResults
        self.fileManager = fileManager
    }

    func conflictPaths(in vaultURL: URL) throws -> [String] {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<[String], Error>?
        coordinator.coordinate(readingItemAt: vaultURL, options: [], error: &coordinationError) {
            coordinatedURL in
            result = Result {
                try scanDirectory(coordinatedURL)
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        guard let result else {
            throw CocoaError(.fileReadUnknown)
        }
        return try result.get()
    }

    private func scanDirectory(_ vaultURL: URL) throws -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let rootPath = vaultURL.standardizedFileURL.path
        var conflicts: [String] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent.localizedCaseInsensitiveContains(".sync-conflict-") else {
                continue
            }
            let standardizedPath = fileURL.standardizedFileURL.path
            let relativePath = standardizedPath.hasPrefix(rootPath + "/")
                ? String(standardizedPath.dropFirst(rootPath.count + 1))
                : fileURL.lastPathComponent
            conflicts.append(relativePath)
            if conflicts.count >= maximumResults {
                break
            }
        }
        return conflicts.sorted()
    }
}
