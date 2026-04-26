import Foundation
import CoreMotion

enum MotionConfidenceThreshold: String, CaseIterable {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HIGH"
        }
    }

    func allows(_ confidence: CMMotionActivityConfidence) -> Bool {
        confidence.rank >= requiredRank
    }

    private var requiredRank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}

enum MovementActivityType: String, CaseIterable {
    case driving
    case cycling
    case running
    case walking

    var title: String {
        rawValue.uppercased()
    }

    var detectionDescription: String {
        "\(rawValue) detected"
    }
}

private extension CMMotionActivityConfidence {
    var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        @unknown default: return 0
        }
    }

    var label: String {
        switch self {
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        @unknown default: return "unknown"
        }
    }
}

@MainActor
final class ActivityDetectionManager: ObservableObject {
    static let shared = ActivityDetectionManager()

    // UserDefaults keys
    static let drivingEnabledKey = "activityTriggerDriving"
    static let cyclingEnabledKey = "activityTriggerCycling"
    static let runningEnabledKey = "activityTriggerRunning"
    static let walkingEnabledKey = "activityTriggerWalking"
    static let minimumConfidenceKey = "activityMinimumConfidence"

    private let activityManager = CMMotionActivityManager()
    private var isMonitoring = false

    /// Called when configured movement is detected
    var onActivityStarted: ((CMMotionActivity) -> Void)?
    /// Called when the user becomes stationary
    var onActivityStopped: (() -> Void)?

    /// Whether the device supports motion activity detection
    var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    func startMonitoring() {
        guard isActivityAvailable else {
            LogManager.shared.warning("[Movement] CoreMotion activity detection is unavailable on this device.")
            return
        }
        guard !isMonitoring else { return }

        isMonitoring = true
        LogManager.shared.info("[Movement] Started CoreMotion monitoring.")

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
        LogManager.shared.info("[Movement] Stopped CoreMotion monitoring.")
    }

    /// Check the current activity once (useful on background wake)
    func queryCurrentActivity() async -> CMMotionActivity? {
        guard isActivityAvailable else {
            LogManager.shared.warning("[Movement] Background activity query skipped because CoreMotion is unavailable.")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let now = Date()
            let fiveMinutesAgo = now.addingTimeInterval(-300)
            activityManager.queryActivityStarting(from: fiveMinutesAgo, to: now, to: .main) { activities, _ in
                if let latest = activities?.last {
                    LogManager.shared.info("[Movement] Background activity query: \(Self.activitySummary(latest)).")
                    continuation.resume(returning: latest)
                } else {
                    LogManager.shared.info("[Movement] Background activity query returned no samples.")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func shouldTriggerPrompt(for activity: CMMotionActivity) -> Bool {
        Self.shouldTriggerPrompt(for: activity)
    }

    static func minimumConfidence(defaults: UserDefaults = .standard) -> MotionConfidenceThreshold {
        guard let rawValue = defaults.string(forKey: minimumConfidenceKey),
              let threshold = MotionConfidenceThreshold(rawValue: rawValue) else {
            return .medium
        }
        return threshold
    }

    static func isActivityEnabled(_ type: MovementActivityType, defaults: UserDefaults = .standard) -> Bool {
        let key: String
        switch type {
        case .driving: key = drivingEnabledKey
        case .cycling: key = cyclingEnabledKey
        case .running: key = runningEnabledKey
        case .walking: key = walkingEnabledKey
        }

        if defaults.object(forKey: key) == nil {
            return true
        }
        return defaults.bool(forKey: key)
    }

    /// Returns true if the activity represents driving or exercise
    static func isActiveActivity(_ activity: CMMotionActivity) -> Bool {
        activity.automotive || activity.cycling || activity.running || activity.walking
    }

    static func primaryActivityType(for activity: CMMotionActivity) -> MovementActivityType? {
        if activity.automotive { return .driving }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        return nil
    }

    static func triggerReason(for activity: CMMotionActivity) -> String {
        primaryActivityType(for: activity)?.detectionDescription ?? "movement detected"
    }

    /// Returns true if the activity represents the user being stationary
    static func isStationary(_ activity: CMMotionActivity) -> Bool {
        activity.stationary && !activity.automotive && !activity.cycling && !activity.running && !activity.walking
    }

    static func shouldTriggerPrompt(for activity: CMMotionActivity) -> Bool {
        let threshold = minimumConfidence()
        guard threshold.allows(activity.confidence) else { return false }

        let drivingMatch = activity.automotive && isActivityEnabled(.driving)
        let cyclingMatch = activity.cycling && isActivityEnabled(.cycling)
        let runningMatch = activity.running && isActivityEnabled(.running)
        let walkingMatch = activity.walking && isActivityEnabled(.walking)

        return drivingMatch || cyclingMatch || runningMatch || walkingMatch
    }

    static func activitySummary(_ activity: CMMotionActivity) -> String {
        var flags: [String] = []
        if activity.automotive { flags.append("driving") }
        if activity.cycling { flags.append("cycling") }
        if activity.running { flags.append("running") }
        if activity.walking { flags.append("walking") }
        if activity.stationary { flags.append("stationary") }
        if activity.unknown || flags.isEmpty { flags.append("unknown") }

        return "types=\(flags.joined(separator: ",")) confidence=\(activity.confidence.label)"
    }

    private func handleActivity(_ activity: CMMotionActivity) {
        if Self.shouldTriggerPrompt(for: activity) {
            LogManager.shared.info("[Movement] Trigger matched: \(Self.activitySummary(activity)).")
            onActivityStarted?(activity)
            return
        }

        // Keep stationary stop conservative to avoid accidental stop events.
        if Self.isStationary(activity), activity.confidence == .high {
            LogManager.shared.info("[Movement] High-confidence stationary event received.")
            onActivityStopped?()
            return
        }

        let threshold = Self.minimumConfidence()
        if !threshold.allows(activity.confidence) {
            LogManager.shared.info("[Movement] Ignored update below confidence threshold \(threshold.rawValue): \(Self.activitySummary(activity)).")
        } else if Self.isActiveActivity(activity) {
            LogManager.shared.info("[Movement] Ignored update because this activity type is disabled: \(Self.activitySummary(activity)).")
        }
    }
}
