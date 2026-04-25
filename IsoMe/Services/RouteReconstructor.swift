import Foundation
import CoreLocation

/// A movement segment between two visits, derived from LocationPoints.
/// Computed on demand; never persisted.
struct RouteSegment: Identifiable, Hashable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let activity: ActivityType
    let distanceMeters: Double
    let pointCount: Int
    let coordinates: [CLLocationCoordinate2D]

    enum ActivityType: Hashable {
        case walking
        case cycling
        case driving

        var symbol: String {
            switch self {
            case .walking: return "figure.walk"
            case .cycling: return "bicycle"
            case .driving: return "car.fill"
            }
        }

        var label: String {
            switch self {
            case .walking: return "Walk"
            case .cycling: return "Bike"
            case .driving: return "Drive"
            }
        }

        var palette: DS.Palette {
            switch self {
            case .walking: return .green
            case .cycling: return .peach
            case .driving: return .blue
            }
        }
    }

    var durationSeconds: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    static func == (lhs: RouteSegment, rhs: RouteSegment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// One row in the timeline — either a place visit or a movement route between visits.
enum TimelineEntry: Identifiable {
    case visit(Visit)
    case route(RouteSegment)

    var id: String {
        switch self {
        case .visit(let v): return "visit-\(v.id.uuidString)"
        case .route(let r): return "route-\(r.id.uuidString)"
        }
    }

    var startTime: Date {
        switch self {
        case .visit(let v): return v.arrivedAt
        case .route(let r): return r.startTime
        }
    }
}

/// Reconstructs a chronological timeline of place visits + movement routes from
/// raw Visit + LocationPoint data. Pure functions; no persistence.
enum RouteReconstructor {
    /// Walking/cycling/driving classification thresholds in m/s.
    static let walkingMaxSpeed: Double = 1.5
    static let cyclingMaxSpeed: Double = 8.0

    /// Builds an interleaved Visit / RouteSegment timeline for a set of visits.
    /// - Visits should be from a single day (or any time window the caller wants displayed).
    /// - Points should cover the visits' time range.
    static func timeline(visits: [Visit], points: [LocationPoint]) -> [TimelineEntry] {
        let sortedVisits = visits.sorted { $0.arrivedAt < $1.arrivedAt }
        guard !sortedVisits.isEmpty else { return [] }

        var entries: [TimelineEntry] = []

        for (index, visit) in sortedVisits.enumerated() {
            entries.append(.visit(visit))

            guard index + 1 < sortedVisits.count else { continue }
            let next = sortedVisits[index + 1]
            guard let depart = visit.departedAt else { continue }

            if let segment = makeSegment(from: depart, to: next.arrivedAt, points: points) {
                entries.append(.route(segment))
            }
        }

        return entries
    }

    /// Builds a single RouteSegment from points falling between two times.
    /// Returns nil if there aren't enough points to form a meaningful segment.
    static func makeSegment(from start: Date, to end: Date, points: [LocationPoint]) -> RouteSegment? {
        let segmentPoints = points
            .filter { !$0.isOutlier && $0.timestamp > start && $0.timestamp < end }
            .sorted { $0.timestamp < $1.timestamp }

        guard segmentPoints.count >= 2 else { return nil }

        let distance = totalDistance(segmentPoints)
        let activity = classifyActivity(from: segmentPoints)

        return RouteSegment(
            id: UUID(),
            startTime: start,
            endTime: end,
            activity: activity,
            distanceMeters: distance,
            pointCount: segmentPoints.count,
            coordinates: segmentPoints.map { $0.coordinate }
        )
    }

    private static func totalDistance(_ points: [LocationPoint]) -> Double {
        zip(points.dropLast(), points.dropFirst())
            .map { $0.distance(to: $1) }
            .reduce(0, +)
    }

    private static func classifyActivity(from points: [LocationPoint]) -> RouteSegment.ActivityType {
        let validSpeeds = points.compactMap { $0.speed }.filter { $0 >= 0 }
        let median = medianSpeed(validSpeeds, fallback: derivedMedianSpeed(from: points))

        if median < walkingMaxSpeed { return .walking }
        if median < cyclingMaxSpeed { return .cycling }
        return .driving
    }

    private static func medianSpeed(_ speeds: [Double], fallback: Double) -> Double {
        guard !speeds.isEmpty else { return fallback }
        let sorted = speeds.sorted()
        return sorted[sorted.count / 2]
    }

    /// When CoreLocation didn't fill in `speed`, derive a median from successive
    /// distance/time deltas across the segment's points.
    private static func derivedMedianSpeed(from points: [LocationPoint]) -> Double {
        let speeds: [Double] = zip(points.dropLast(), points.dropFirst()).compactMap { a, b in
            let dt = b.timestamp.timeIntervalSince(a.timestamp)
            guard dt > 0 else { return nil }
            return a.distance(to: b) / dt
        }
        guard !speeds.isEmpty else { return 0 }
        let sorted = speeds.sorted()
        return sorted[sorted.count / 2]
    }
}
