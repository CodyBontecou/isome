import Foundation

enum WatchManualVisitCommandAction: String, Codable, Equatable, Sendable {
    case checkIn
    case checkOut
}

struct WatchManualVisitCommand: Codable, Equatable, Sendable {
    static let payloadKey = "isome.watch.manualVisitCommand"

    var id: UUID
    var action: WatchManualVisitCommandAction
    var createdAt: Date
    var placeName: String?

    init(
        id: UUID = UUID(),
        action: WatchManualVisitCommandAction,
        createdAt: Date = Date(),
        placeName: String? = nil
    ) {
        self.id = id
        self.action = action
        self.createdAt = createdAt
        self.placeName = placeName
    }

    var propertyListPayload: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.payloadKey: data]
    }

    static func decode(from propertyList: [String: Any]) -> WatchManualVisitCommand? {
        guard let data = propertyList[payloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchManualVisitCommand.self, from: data)
    }
}

struct WatchManualVisitCommandResponse: Codable, Equatable, Sendable {
    static let payloadKey = "isome.watch.manualVisitCommandResponse"

    var commandID: UUID
    var success: Bool
    var message: String

    var propertyListPayload: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.payloadKey: data]
    }

    static func decode(from propertyList: [String: Any]) -> WatchManualVisitCommandResponse? {
        guard let data = propertyList[payloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchManualVisitCommandResponse.self, from: data)
    }
}

/// Shared data model for transferring tracking state between iOS and watchOS
struct SharedLocationData: Codable {
    static let watchContextPayloadKey = "isome.sharedLocationData"

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
    var stopAfterHours: Double?
    var usesMetricDistanceUnits: Bool? = nil
    var currentVisitID: UUID? = nil
    var currentVisitName: String? = nil
    var currentVisitSourceRaw: String? = nil
    var currentVisitConfirmationStatusRaw: String? = nil
    var currentVisitArrivedAt: Date? = nil
    var hasOpenManualVisit: Bool? = nil
    var openManualVisitID: UUID? = nil
    var openManualVisitName: String? = nil
    var openManualVisitArrivedAt: Date? = nil

    static let appGroupIdentifier = "group.com.bontecou.isome"
    private static let userDefaultsKey = "sharedLocationData"

    /// Save to shared App Group UserDefaults
    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else { return }
        if let encoded = try? JSONEncoder().encode(self) {
            defaults.set(encoded, forKey: Self.userDefaultsKey)
        }
    }

    var propertyListPayload: [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.watchContextPayloadKey: data]
    }

    static func decode(from propertyList: [String: Any]) -> SharedLocationData? {
        guard let data = propertyList[watchContextPayloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(SharedLocationData.self, from: data)
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
            stopAfterHours: nil,
            usesMetricDistanceUnits: true,
            currentVisitID: nil,
            currentVisitName: nil,
            currentVisitSourceRaw: nil,
            currentVisitConfirmationStatusRaw: nil,
            currentVisitArrivedAt: nil,
            hasOpenManualVisit: false,
            openManualVisitID: nil,
            openManualVisitName: nil,
            openManualVisitArrivedAt: nil
        )
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
        isTrackingEnabled ? String(localized: "Tracking") : String(localized: "Off")
    }

    var isManualCheckInOpen: Bool {
        hasOpenManualVisit ?? (openManualVisitArrivedAt != nil)
    }

    var openManualVisitDisplayName: String {
        openManualVisitName ?? String(localized: "Manual Check-In")
    }

    var remainingTime: TimeInterval? {
        guard let startTime = trackingStartTime,
              let hours = stopAfterHours,
              hours > 0 else {
            return nil
        }
        let elapsed = Date().timeIntervalSince(startTime)
        let total = hours * 3600
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
