import Combine
import Foundation

@MainActor
final class SyncProfileManager: ObservableObject {
    @Published private(set) var profile: SyncProfile?
    @Published private(set) var lastError: String?

    private let store: SyncProfileStore

    init(store: SyncProfileStore = SyncProfileStore()) {
        self.store = store
        do {
            profile = try store.load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func save(_ profile: SyncProfile) throws {
        let validated = try profile.validated()
        try store.save(validated)
        self.profile = validated
        lastError = nil
    }

    func clear() {
        do {
            try store.clear()
            profile = nil
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}
