import Foundation

struct VaultSpikeReport: Equatable {
    let completedOperations: [String]
}

struct VaultSpikeRunner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func run(in vaultURL: URL) throws -> VaultSpikeReport {
        let root = vaultURL.appendingPathComponent(".vault-sync-access-test", isDirectory: true)
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        let original = nested.appendingPathComponent("created.md", isDirectory: false)
        let renamed = nested.appendingPathComponent("renamed.md", isDirectory: false)
        let initialText = "# Vault access test\n\nCreated by the iPad feasibility spike.\n"
        let editedText = initialText + "\nRead, edited, and ready to rename.\n"

        try? fileManager.removeItem(at: root)
        do {
            try coordinateWriting(at: vaultURL, options: .forMerging) { _ in
                try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
                try Data(initialText.utf8).write(to: original, options: .atomic)
            }

            let firstRead = try coordinateReading(at: original) { coordinatedURL in
                try String(contentsOf: coordinatedURL, encoding: .utf8)
            }
            guard firstRead == initialText else {
                throw CocoaError(.fileReadCorruptFile)
            }

            try coordinateWriting(at: original, options: .forReplacing) { coordinatedURL in
                try Data(editedText.utf8).write(to: coordinatedURL, options: .atomic)
            }

            try coordinateMove(from: original, to: renamed) { coordinatedSource, coordinatedDestination in
                try fileManager.moveItem(at: coordinatedSource, to: coordinatedDestination)
            }

            let finalRead = try coordinateReading(at: renamed) { coordinatedURL in
                try String(contentsOf: coordinatedURL, encoding: .utf8)
            }
            guard finalRead == editedText else {
                throw CocoaError(.fileReadCorruptFile)
            }

            try coordinateWriting(at: root, options: .forDeleting) { coordinatedURL in
                try fileManager.removeItem(at: coordinatedURL)
            }
        } catch {
            try? fileManager.removeItem(at: root)
            throw error
        }

        return VaultSpikeReport(
            completedOperations: ["create", "read", "edit", "rename", "delete"]
        )
    }

    private func coordinateReading<T>(
        at url: URL,
        operation: (URL) throws -> T
    ) throws -> T {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) {
            coordinatedURL in
            result = Result { try operation(coordinatedURL) }
        }
        if let coordinationError {
            throw coordinationError
        }
        return try result!.get()
    }

    private func coordinateWriting(
        at url: URL,
        options: NSFileCoordinator.WritingOptions,
        operation: (URL) throws -> Void
    ) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) {
            coordinatedURL in
            do {
                try operation(coordinatedURL)
            } catch {
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }

    private func coordinateMove(
        from source: URL,
        to destination: URL,
        operation: (URL, URL) throws -> Void
    ) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(
            writingItemAt: source,
            options: .forMoving,
            writingItemAt: destination,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedSource, coordinatedDestination in
            do {
                try operation(coordinatedSource, coordinatedDestination)
            } catch {
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }
}
