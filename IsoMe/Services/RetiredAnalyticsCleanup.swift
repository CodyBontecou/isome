import Foundation

/// Upgrade migration only: removes retired analytics state without creating identifiers or sending requests.
enum RetiredAnalyticsCleanup {
    static func run(defaults: UserDefaults = .standard) {
        for key in [
            "onboarding.analytics.install_id.v1",
            "onboarding.analytics.queue.v1",
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
