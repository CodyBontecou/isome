import Foundation
import CoreLocation

final class DailyDistanceTracker {
    static let shared = DailyDistanceTracker()

    private let defaults = UserDefaults.standard
    private let historyKey = "dailyDistanceHistory"
    private let lastCheckpointKey = "distanceTrackerLastCheckpoint"

    /// Only count movement beyond this distance to normalize across tracking modes
    private let minimumCheckpointDistance: Double = 200
    private let rollingWindowDays = 7
    private let triggerMultiplier = 1.5
    private let minimumHistoryDays = 3
    /// Require a meaningful baseline before triggering (meters)
    private let minimumBaselineMeters = 100.0

    /// Record a location update. Only accumulates distance when the user has
    /// moved at least 200m from the previous checkpoint (normalizes across
    /// continuous tracking and significant-change modes).
    func recordLocation(_ location: CLLocation) {
        if let lastCoords = defaults.array(forKey: lastCheckpointKey) as? [Double],
           lastCoords.count == 2 {
            let lastLocation = CLLocation(latitude: lastCoords[0], longitude: lastCoords[1])
            let distance = location.distance(from: lastLocation)

            // Only record if moved significantly and not a GPS glitch
            guard distance >= minimumCheckpointDistance, distance < 100_000 else { return }

            let today = dateKey(for: Date())
            var history = loadHistory()
            history[today, default: 0] += distance
            saveHistory(history)
            defaults.set([location.coordinate.latitude, location.coordinate.longitude], forKey: lastCheckpointKey)
            cleanupOldEntries()
        } else {
            // First location ever — set the checkpoint
            defaults.set([location.coordinate.latitude, location.coordinate.longitude], forKey: lastCheckpointKey)
        }
    }

    /// Returns true when today's cumulative distance exceeds the rolling
    /// average of the past days by the trigger multiplier (1.5x).
    func isAboveAverage() -> Bool {
        let today = dateKey(for: Date())
        let history = loadHistory()
        let todayDistance = history[today, default: 0]

        guard todayDistance > 0 else { return false }

        let pastDays = history.filter { $0.key != today }
        guard pastDays.count >= minimumHistoryDays else { return false }

        let average = pastDays.values.reduce(0, +) / Double(pastDays.count)
        guard average > minimumBaselineMeters else { return false }

        return todayDistance > average * triggerMultiplier
    }

    // MARK: - Helpers

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private func loadHistory() -> [String: Double] {
        defaults.dictionary(forKey: historyKey) as? [String: Double] ?? [:]
    }

    private func saveHistory(_ history: [String: Double]) {
        defaults.set(history, forKey: historyKey)
    }

    private func cleanupOldEntries() {
        let history = loadHistory()
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -(rollingWindowDays + 1), to: Date()) else { return }
        let cutoffKey = dateKey(for: cutoff)
        let cleaned = history.filter { $0.key > cutoffKey }
        if cleaned.count != history.count {
            saveHistory(cleaned)
        }
    }
}
