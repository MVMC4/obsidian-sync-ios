import XCTest
@testable import ObsidianSync

final class OnboardingStoreTests: XCTestCase {
    func testShowsOnFirstLaunchAndHidesAfterCompletion() {
        let defaults = UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!
        let store = OnboardingStore(defaults: defaults)
        XCTAssertTrue(store.shouldShow)
        store.markComplete()
        XCTAssertFalse(store.shouldShow)
        let reloaded = OnboardingStore(defaults: defaults)
        XCTAssertFalse(reloaded.shouldShow)
    }

    func testReplayShowsAgainAndSchemaBumpResets() {
        let defaults = UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!
        defaults.set(OnboardingStore.currentSchemaVersion,
                     forKey: "onboarding.completedSchemaVersion")
        let store = OnboardingStore(defaults: defaults)
        XCTAssertFalse(store.shouldShow)
        store.replay()
        XCTAssertTrue(store.shouldShow)
        defaults.set(OnboardingStore.currentSchemaVersion - 1,
                     forKey: "onboarding.completedSchemaVersion")
        XCTAssertTrue(OnboardingStore(defaults: defaults).shouldShow)
    }
}
