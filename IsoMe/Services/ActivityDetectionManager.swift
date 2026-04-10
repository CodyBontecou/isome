import Foundation
import CoreMotion

@MainActor
final class ActivityDetectionManager: ObservableObject {
    static let shared = ActivityDetectionManager()

    private let activityManager = CMMotionActivityManager()
    private var isMonitoring = false

    /// Called when the user starts driving or exercising
    var onActivityStarted: ((CMMotionActivity) -> Void)?
    /// Called when the user becomes stationary
    var onActivityStopped: (() -> Void)?

    /// Whether the device supports motion activity detection
    var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    func startMonitoring() {
        guard isActivityAvailable, !isMonitoring else { return }
        isMonitoring = true

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in
                self.handleActivity(activity)
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        activityManager.stopActivityUpdates()
        isMonitoring = false
    }

    /// Check the current activity once (useful on background wake)
    func queryCurrentActivity() async -> CMMotionActivity? {
        guard isActivityAvailable else { return nil }

        return await withCheckedContinuation { continuation in
            let now = Date()
            let fiveMinutesAgo = now.addingTimeInterval(-300)
            activityManager.queryActivityStarting(from: fiveMinutesAgo, to: now, to: .main) { activities, _ in
                continuation.resume(returning: activities?.last)
            }
        }
    }

    /// Returns true if the activity represents driving or exercise
    static func isActiveActivity(_ activity: CMMotionActivity) -> Bool {
        activity.automotive || activity.cycling || activity.running || activity.walking
    }

    /// Returns true if the activity represents the user being stationary
    static func isStationary(_ activity: CMMotionActivity) -> Bool {
        activity.stationary && !activity.automotive && !activity.cycling && !activity.running && !activity.walking
    }

    private func handleActivity(_ activity: CMMotionActivity) {
        // Only act on high-confidence readings
        guard activity.confidence == .high else { return }

        if Self.isActiveActivity(activity) {
            onActivityStarted?(activity)
        } else if Self.isStationary(activity) {
            onActivityStopped?()
        }
    }
}
