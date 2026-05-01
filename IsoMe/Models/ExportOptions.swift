import Foundation

struct ExportOptions {
    enum DataKind: String, CaseIterable, Identifiable {
        case visits, points, all
        var id: String { rawValue }
    }

    enum DateRangePreset: String, CaseIterable, Identifiable {
        case allTime
        case today
        case last7Days
        case last30Days
        case thisMonth
        case custom

        var id: String { rawValue }

        var label: String {
            switch self {
            case .allTime: return "ALL TIME"
            case .today: return "TODAY"
            case .last7Days: return "LAST 7 DAYS"
            case .last30Days: return "LAST 30 DAYS"
            case .thisMonth: return "THIS MONTH"
            case .custom: return "CUSTOM"
            }
        }
    }

    // Selection
    var dataKind: DataKind = .visits
    var format: ExportFormat = .json

    // Date range
    var datePreset: DateRangePreset = .allTime
    var customStart: Date = Calendar.current.startOfDay(for: Date().addingTimeInterval(-7 * 86_400))
    var customEnd: Date = Date()

    // Time-of-day window (only hour/minute components used)
    var timeOfDayEnabled: Bool = false
    var timeOfDayStart: Date = ExportOptions.defaultTimeOfDayStart
    var timeOfDayEnd: Date = ExportOptions.defaultTimeOfDayEnd

    // Visit field toggles
    var includeVisitCoordinates: Bool = true
    var includeVisitDuration: Bool = true
    var includeVisitLocationName: Bool = true
    var includeVisitAddress: Bool = true
    var includeVisitNotes: Bool = true

    // Point field toggles
    var includePointAltitude: Bool = true
    var includePointSpeed: Bool = true
    var includePointAccuracy: Bool = true
    var includePointOutlierFlag: Bool = true

    // Filters
    var excludeOutliers: Bool = false
    var onlyCompletedVisits: Bool = false
    var minVisitDurationMinutes: Double = 0
    var maxAccuracyMeters: Double = 0  // 0 means no cap

    // MARK: - Defaults

    private static let defaultTimeOfDayStart: Date = {
        var comps = DateComponents()
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private static let defaultTimeOfDayEnd: Date = {
        var comps = DateComponents()
        comps.hour = 17
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    // MARK: - Resolved Range

    func resolvedDateRange(now: Date = Date()) -> ClosedRange<Date>? {
        let cal = Calendar.current
        switch datePreset {
        case .allTime:
            return nil
        case .today:
            let start = cal.startOfDay(for: now)
            return start...now
        case .last7Days:
            let start = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now)) ?? now
            return start...now
        case .last30Days:
            let start = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: now)) ?? now
            return start...now
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: now)
            return start...now
        case .custom:
            let lo = min(customStart, customEnd)
            let hi = max(customStart, customEnd)
            return lo...hi
        }
    }

    // MARK: - Time-of-day check

    private func minutesOfDay(from date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func matchesTimeOfDay(_ date: Date) -> Bool {
        guard timeOfDayEnabled else { return true }
        let m = minutesOfDay(from: date)
        let lo = minutesOfDay(from: timeOfDayStart)
        let hi = minutesOfDay(from: timeOfDayEnd)
        if lo == hi { return true }
        if lo < hi {
            return m >= lo && m <= hi
        }
        // Wraps midnight (e.g. 22:00–06:00)
        return m >= lo || m <= hi
    }

    // MARK: - Filtering

    func filterVisits(_ visits: [Visit]) -> [Visit] {
        let range = resolvedDateRange()
        return visits.filter { visit in
            if let range = range, !range.contains(visit.arrivedAt) { return false }
            if !matchesTimeOfDay(visit.arrivedAt) { return false }
            if onlyCompletedVisits && visit.departedAt == nil { return false }
            if minVisitDurationMinutes > 0 {
                let mins = visit.durationMinutes ?? 0
                if mins < minVisitDurationMinutes { return false }
            }
            return true
        }
    }

    func filterPoints(_ points: [LocationPoint]) -> [LocationPoint] {
        let range = resolvedDateRange()
        return points.filter { point in
            if let range = range, !range.contains(point.timestamp) { return false }
            if !matchesTimeOfDay(point.timestamp) { return false }
            if excludeOutliers && point.isOutlier { return false }
            if maxAccuracyMeters > 0 && point.horizontalAccuracy > maxAccuracyMeters { return false }
            return true
        }
    }
}
