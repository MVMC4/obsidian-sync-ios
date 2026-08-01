import Foundation

final class OnboardingStore: ObservableObject {
    static let currentSchemaVersion = 2
    private let defaults: UserDefaults
    private let completedKey = "onboarding.completedSchemaVersion"

    @Published var shouldShow: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let done = defaults.integer(forKey: completedKey)
        shouldShow = done < Self.currentSchemaVersion
    }

    func markComplete() {
        defaults.set(Self.currentSchemaVersion, forKey: completedKey)
        shouldShow = false
    }

    func replay() {
        shouldShow = true
    }

    func resetForTesting() {
        defaults.removeObject(forKey: completedKey)
        shouldShow = true
    }
}
