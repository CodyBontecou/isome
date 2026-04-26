import Foundation

/// Shared data model for transferring tracking state between iOS and watchOS
struct SharedLocationData: Codable {
    var isTrackingEnabled: Bool
    var currentLocationName: String?
    var currentAddress: String?
    var lastLatitude: Double?
    var lastLongitude: Double?
    var lastUpdateTime: Date?
    var todayVisitsCount: Int
    var todayDistanceMeters: Double
    var todayPointsCount: Int
    var trackingStartTime: Date?
    var trackingAutoOffHours: Double?
    var usesMetricDistanceUnits: Bool? = nil

    static let appGroupIdentifier = "group.com.bontecou.isome"
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
            currentLocationName: nil,
            currentAddress: nil,
            lastLatitude: nil,
            lastLongitude: nil,
            lastUpdateTime: nil,
            todayVisitsCount: 0,
            todayDistanceMeters: 0,
            todayPointsCount: 0,
            trackingStartTime: nil,
            trackingAutoOffHours: nil,
            usesMetricDistanceUnits: true
        )
    }
}

// MARK: - Codable Backward Compatibility

extension SharedLocationData {
    /// Current payload keys.
    private enum CodingKeys: String, CodingKey {
        case isTrackingEnabled
        case currentLocationName
        case currentAddress
        case lastLatitude
        case lastLongitude
        case lastUpdateTime
        case todayVisitsCount
        case todayDistanceMeters
        case todayPointsCount
        case trackingStartTime
        case trackingAutoOffHours
        case usesMetricDistanceUnits
    }

    /// Legacy payload keys kept for compatibility with previously persisted App Group payloads.
    private enum LegacyCodingKeys: String, CodingKey {
        case isContinuousTrackingEnabled
        case continuousTrackingStartTime
        case continuousTrackingAutoOffHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)

        if let isTrackingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTrackingEnabled) {
            self.isTrackingEnabled = isTrackingEnabled
        } else {
            self.isTrackingEnabled = try legacy.decodeIfPresent(Bool.self, forKey: .isContinuousTrackingEnabled) ?? false
        }

        self.currentLocationName = try container.decodeIfPresent(String.self, forKey: .currentLocationName)
        self.currentAddress = try container.decodeIfPresent(String.self, forKey: .currentAddress)
        self.lastLatitude = try container.decodeIfPresent(Double.self, forKey: .lastLatitude)
        self.lastLongitude = try container.decodeIfPresent(Double.self, forKey: .lastLongitude)
        self.lastUpdateTime = try container.decodeIfPresent(Date.self, forKey: .lastUpdateTime)
        self.todayVisitsCount = try container.decodeIfPresent(Int.self, forKey: .todayVisitsCount) ?? 0
        self.todayDistanceMeters = try container.decodeIfPresent(Double.self, forKey: .todayDistanceMeters) ?? 0
        self.todayPointsCount = try container.decodeIfPresent(Int.self, forKey: .todayPointsCount) ?? 0

        self.trackingStartTime =
            try container.decodeIfPresent(Date.self, forKey: .trackingStartTime) ??
            (try legacy.decodeIfPresent(Date.self, forKey: .continuousTrackingStartTime))

        self.trackingAutoOffHours =
            try container.decodeIfPresent(Double.self, forKey: .trackingAutoOffHours) ??
            (try legacy.decodeIfPresent(Double.self, forKey: .continuousTrackingAutoOffHours))

        self.usesMetricDistanceUnits = try container.decodeIfPresent(Bool.self, forKey: .usesMetricDistanceUnits)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isTrackingEnabled, forKey: .isTrackingEnabled)
        try container.encodeIfPresent(currentLocationName, forKey: .currentLocationName)
        try container.encodeIfPresent(currentAddress, forKey: .currentAddress)
        try container.encodeIfPresent(lastLatitude, forKey: .lastLatitude)
        try container.encodeIfPresent(lastLongitude, forKey: .lastLongitude)
        try container.encodeIfPresent(lastUpdateTime, forKey: .lastUpdateTime)
        try container.encode(todayVisitsCount, forKey: .todayVisitsCount)
        try container.encode(todayDistanceMeters, forKey: .todayDistanceMeters)
        try container.encode(todayPointsCount, forKey: .todayPointsCount)
        try container.encodeIfPresent(trackingStartTime, forKey: .trackingStartTime)
        try container.encodeIfPresent(trackingAutoOffHours, forKey: .trackingAutoOffHours)
        try container.encodeIfPresent(usesMetricDistanceUnits, forKey: .usesMetricDistanceUnits)

        // Also emit legacy keys so older decoders can continue reading shared payloads.
        var legacy = encoder.container(keyedBy: LegacyCodingKeys.self)
        try legacy.encode(isTrackingEnabled, forKey: .isContinuousTrackingEnabled)
        try legacy.encodeIfPresent(trackingStartTime, forKey: .continuousTrackingStartTime)
        try legacy.encodeIfPresent(trackingAutoOffHours, forKey: .continuousTrackingAutoOffHours)
    }
}

// MARK: - Convenience Properties

extension SharedLocationData {
    var displayLocationName: String {
        currentLocationName ?? currentAddress ?? String(localized: "Unknown")
    }

    var prefersMetricDistanceUnits: Bool {
        usesMetricDistanceUnits ?? true
    }

    var formattedDistance: String {
        DistanceFormatter.format(meters: todayDistanceMeters, usesMetric: prefersMetricDistanceUnits)
    }

    var trackingStatus: String {
        if isTrackingEnabled {
            return String(localized: "Tracking")
        } else {
            return String(localized: "Off")
        }
    }

    var remainingTime: TimeInterval? {
        guard let startTime = trackingStartTime,
              let autoOffHours = trackingAutoOffHours,
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
