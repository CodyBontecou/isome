import XCTest
@testable import IsoMe

@MainActor
final class OnboardingLaunchConfigurationTests: XCTestCase {
    func testOnboardingCanCompleteAfterForcedReplayWithoutTracking() throws {
        let suite = "OnboardingLaunchConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer {
            defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
            defaults.removePersistentDomain(forName: suite)
        }
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(false, forKey: "isTrackingEnabled")
        defaults.setVolatileDomain([
            "hasCompletedOnboarding": "NO",
            "unrelatedLaunchPreference": "keep"
        ], forName: UserDefaults.argumentDomain)

        OnboardingLaunchConfiguration.consumeOverride(defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertEqual(defaults.string(forKey: "unrelatedLaunchPreference"), "keep")
        // The completion write must be observable immediately, without changing tracking.
        defaults.set(true, forKey: "hasCompletedOnboarding")
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertFalse(defaults.bool(forKey: "isTrackingEnabled"))
        // A repeated startup call must not replay the already consumed override.
        OnboardingLaunchConfiguration.consumeOverride(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    func testNormalLaunchPreservesCompletedOnboarding() throws {
        let suite = "OnboardingLaunchConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let originalArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer {
            defaults.setVolatileDomain(originalArguments, forName: UserDefaults.argumentDomain)
            defaults.removePersistentDomain(forName: suite)
        }
        defaults.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
        defaults.set(true, forKey: "hasCompletedOnboarding")

        OnboardingLaunchConfiguration.consumeOverride(defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }
}
