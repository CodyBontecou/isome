import Foundation

/// Shared data model for transferring tracking state between iOS and watchOS
struct SharedLocationData: Codable {
    var isTrackingEnabled: Bool
    var isContinuousTrackingEnabled: Bool
    var currentLocationName: String?
    var currentAddress: String?
    var lastLatitude: Double?
    var lastLongitude: Double?
    var lastUpdateTime: Date?
    var todayVisitsCount: Int
    var todayDistanceMeters: Double
    var todayPointsCount: Int
    var continuousTrackingStartTime: Date?
    var continuousTrackingAutoOffHours: Double?
    
    static let appGroupIdentifier = "group.com.bontecou.OwnPath"
    private static let userDefaultsKey = "sharedLocationData"
    
    /// Save to shared App Group UserDefaults
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
    
    /// Load from shared App Group UserDefaults
    static func load() -> SharedLocationData? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
              let data = defaults.data(forKey: Self.userDefaultsKey),
              let decoded = try? JSONDecoder().decode(SharedLocationData.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    /// Default empty state
    static var empty: SharedLocationData {
        SharedLocationData(
            isTrackingEnabled: false,
            isContinuousTrackingEnabled: false,
            currentLocationName: nil,
            currentAddress: nil,
            lastLatitude: nil,
            lastLongitude: nil,
            lastUpdateTime: nil,
            todayVisitsCount: 0,
            todayDistanceMeters: 0,
            todayPointsCount: 0,
            continuousTrackingStartTime: nil,
            continuousTrackingAutoOffHours: nil
        )
    }
}

// MARK: - Convenience Properties

extension SharedLocationData {
    var displayLocationName: String {
        currentLocationName ?? currentAddress ?? "Unknown"
    }
    
    var formattedDistance: String {
        if todayDistanceMeters >= 1000 {
            return String(format: "%.1f km", todayDistanceMeters / 1000)
        }
        return String(format: "%.0f m", todayDistanceMeters)
    }
    
    var trackingStatus: String {
        if isContinuousTrackingEnabled {
            return "Continuous"
        } else if isTrackingEnabled {
            return "Visits"
        } else {
            return "Off"
        }
    }
    
    var remainingTime: TimeInterval? {
        guard let startTime = continuousTrackingStartTime,
              let autoOffHours = continuousTrackingAutoOffHours,
              autoOffHours > 0 else {
            return nil
        }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = autoOffHours * 3600
        return max(0, total - elapsed)
    }
    
    var formattedRemainingTime: String? {
        guard let remaining = remainingTime else { return nil }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
