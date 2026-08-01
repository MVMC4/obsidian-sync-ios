import Combine
import Foundation

enum VaultAccessError: LocalizedError {
    case noSelection
    case accessDenied
    case unsupportedBookmarkVersion(Int)

    var errorDescription: String? {
        switch self {
        case .noSelection:
            return "Choose an Obsidian vault before running the access test."
        case .accessDenied:
            return "iPadOS did not grant access to this folder. Choose the vault again."
        case let .unsupportedBookmarkVersion(version):
            return "The saved vault permission uses unsupported schema version \(version)."
        }
    }
}

final class VaultAccessSession {
    let url: URL
    private var isOpen = true

    init(url: URL) {
        self.url = url
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        url.stopAccessingSecurityScopedResource()
    }

    deinit {
        close()
    }
}

@MainActor
final class VaultAccessCoordinator: ObservableObject {
    @Published private(set) var selectedVaultName: String?
    @Published private(set) var lastError: String?

    private let store: VaultBookmarkStore

    init(store: VaultBookmarkStore = VaultBookmarkStore()) {
        self.store = store
        selectedVaultName = (try? store.load())?.displayName
    }

    var hasSelection: Bool {
        selectedVaultName != nil
    }

    func rememberSelection(_ url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw VaultAccessError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let bookmark = try url.bookmarkData(options: .minimalBookmark)
            let record = VaultBookmarkRecord(
                bookmarkData: bookmark,
                displayName: url.lastPathComponent
            )
            try store.save(record)
            selectedVaultName = record.displayName
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func openSession() throws -> VaultAccessSession {
        guard let record = try store.load() else {
            throw VaultAccessError.noSelection
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: record.bookmarkData,
            bookmarkDataIsStale: &isStale
        )
        guard url.startAccessingSecurityScopedResource() else {
            throw VaultAccessError.accessDenied
        }

        if isStale {
            do {
                let refreshed = try url.bookmarkData(options: .minimalBookmark)
                try store.save(
                    VaultBookmarkRecord(
                        bookmarkData: refreshed,
                        displayName: url.lastPathComponent
                    )
                )
            } catch {
                url.stopAccessingSecurityScopedResource()
                throw error
            }
        }

        selectedVaultName = url.lastPathComponent
        lastError = nil
        return VaultAccessSession(url: url)
    }

    func forgetSelection() {
        do {
            try store.clear()
            selectedVaultName = nil
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
