import Foundation
import SwiftData

@Model
final class RecordingSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var customName: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        customName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.customName = customName
        self.notes = notes
    }

    var isActive: Bool {
        endedAt == nil
    }

    var normalizedCustomName: String? {
        guard let trimmed = customName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    func displayName(defaultName: String) -> String {
        normalizedCustomName ?? defaultName
    }
}

struct RecordingSessionSummary: Identifiable {
    let id: String
    let storedSession: RecordingSession?
    let sequenceNumber: Int
    let startedAt: Date
    let endedAt: Date?
    let points: [LocationPoint]
    let isInferred: Bool
    let isActive: Bool
    let now: Date

    var title: String {
        storedSession?.displayName(defaultName: defaultTitle) ?? defaultTitle
    }

    var defaultTitle: String {
        "Outing \(sequenceNumber)"
    }

    var effectiveEndDate: Date {
        let fallback = points.last?.timestamp ?? now
        return max(startedAt, endedAt ?? fallback)
    }

    var dateRange: ClosedRange<Date> {
        startedAt...effectiveEndDate
    }

    var duration: TimeInterval {
        max(0, effectiveEndDate.timeIntervalSince(startedAt))
    }

    var distanceMeters: Double {
        RecordingSessionBuilder.totalDistance(in: distancePoints)
    }

    var averageSpeedMetersPerSecond: Double? {
        guard duration > 0, distanceMeters > 0 else { return nil }
        return distanceMeters / duration
    }

    var pointCount: Int {
        points.count
    }

    var outlierCount: Int {
        points.filter(\.isOutlier).count
    }

    var distancePoints: [LocationPoint] {
        let filtered = points.filter { !$0.isOutlier }
        return filtered.isEmpty ? points : filtered
    }

    var startPoint: LocationPoint? {
        points.first
    }

    var endPoint: LocationPoint? {
        points.last
    }

    var formattedTimeRange: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let date = dateFormatter.string(from: startedAt)
        let start = timeFormatter.string(from: startedAt)

        if isActive {
            return "\(date) • \(start) – now"
        }

        let end = timeFormatter.string(from: effectiveEndDate)
        if Calendar.current.isDate(startedAt, inSameDayAs: effectiveEndDate) {
            return "\(date) • \(start) – \(end)"
        }

        return "\(date) • \(start) – \(effectiveEndDate.formatted(date: .abbreviated, time: .shortened))"
    }

    var accessibilityValue: String {
        var parts = [
            formattedTimeRange,
            "Duration \(RecordingSessionFormatter.duration(duration))",
            "Distance \(DistanceFormatter.format(meters: distanceMeters, usesMetric: true))",
            "\(pointCount) \(pointCount == 1 ? "point" : "points")"
        ]

        if isActive {
            parts.append("Currently recording")
        }

        if isInferred {
            parts.append("Inferred from a gap in location points")
        }

        return parts.joined(separator: ". ")
    }
}

enum RecordingSessionSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case longest
    case distance
    case points

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .longest: return "Longest"
        case .distance: return "Distance"
        case .points: return "Points"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        case .longest: return "Longest duration first"
        case .distance: return "Longest distance first"
        case .points: return "Most points first"
        }
    }

    func sorted(_ sessions: [RecordingSessionSummary]) -> [RecordingSessionSummary] {
        switch self {
        case .newest:
            return sessions.sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt { return lhs.sequenceNumber > rhs.sequenceNumber }
                return lhs.startedAt > rhs.startedAt
            }
        case .oldest:
            return sessions.sorted { lhs, rhs in
                if lhs.startedAt == rhs.startedAt { return lhs.sequenceNumber < rhs.sequenceNumber }
                return lhs.startedAt < rhs.startedAt
            }
        case .longest:
            return sessions.sorted { lhs, rhs in
                if lhs.duration == rhs.duration { return lhs.startedAt > rhs.startedAt }
                return lhs.duration > rhs.duration
            }
        case .distance:
            return sessions.sorted { lhs, rhs in
                if lhs.distanceMeters == rhs.distanceMeters { return lhs.startedAt > rhs.startedAt }
                return lhs.distanceMeters > rhs.distanceMeters
            }
        case .points:
            return sessions.sorted { lhs, rhs in
                if lhs.pointCount == rhs.pointCount { return lhs.startedAt > rhs.startedAt }
                return lhs.pointCount > rhs.pointCount
            }
        }
    }
}

enum RecordingSessionGapPreset: String, CaseIterable, Identifiable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        }
    }

    var label: String {
        switch self {
        case .fifteenMinutes: return "15m gaps"
        case .thirtyMinutes: return "30m gaps"
        case .oneHour: return "1h gaps"
        case .twoHours: return "2h gaps"
        }
    }
}

enum RecordingSessionFormatter {
    static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            if minutes == 0 { return "\(hours)h" }
            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m"
        }

        return "\(seconds)s"
    }

    static func clockDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

enum RecordingSessionBuilder {
    static let defaultGapThreshold: TimeInterval = 30 * 60

    static func summaries(
        storedSessions: [RecordingSession],
        points: [LocationPoint],
        activeTrackingStart: Date?,
        gapThreshold: TimeInterval = defaultGapThreshold,
        now: Date = Date()
    ) -> [RecordingSessionSummary] {
        let orderedPoints = points.sorted { $0.timestamp < $1.timestamp }
        let orderedStoredSessions = storedSessions.sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.startedAt < rhs.startedAt
        }

        var consumedPointIDs = Set<UUID>()
        var pending: [PendingSessionSummary] = []

        for storedSession in orderedStoredSessions {
            let endDate = storedSession.endedAt ?? now
            let sessionPoints = orderedPoints.filter { point in
                point.timestamp >= storedSession.startedAt && point.timestamp <= endDate
            }
            sessionPoints.forEach { consumedPointIDs.insert($0.id) }

            pending.append(PendingSessionSummary(
                id: "stored-\(storedSession.id.uuidString)",
                storedSession: storedSession,
                startedAt: storedSession.startedAt,
                endedAt: storedSession.endedAt,
                points: sessionPoints,
                isInferred: false,
                isActive: storedSession.endedAt == nil
            ))
        }

        let remainingPoints = orderedPoints.filter { !consumedPointIDs.contains($0.id) }
        let inferredChunks = inferredPointChunks(
            from: remainingPoints,
            activeTrackingStart: activeTrackingStart,
            gapThreshold: gapThreshold
        )

        for chunk in inferredChunks {
            guard let first = chunk.first, let last = chunk.last else { continue }
            let containsActiveTrackingStart = activeTrackingStart.map { activeStart in
                first.timestamp >= activeStart || (first.timestamp < activeStart && last.timestamp >= activeStart)
            } ?? false

            pending.append(PendingSessionSummary(
                id: "inferred-\(first.id.uuidString)-\(last.id.uuidString)-\(chunk.count)",
                storedSession: nil,
                startedAt: first.timestamp,
                endedAt: containsActiveTrackingStart ? nil : last.timestamp,
                points: chunk,
                isInferred: true,
                isActive: containsActiveTrackingStart
            ))
        }

        let chronological = pending.sorted { lhs, rhs in
            if lhs.startedAt == rhs.startedAt { return lhs.id < rhs.id }
            return lhs.startedAt < rhs.startedAt
        }

        return chronological.enumerated().map { offset, item in
            RecordingSessionSummary(
                id: item.id,
                storedSession: item.storedSession,
                sequenceNumber: offset + 1,
                startedAt: item.startedAt,
                endedAt: item.endedAt,
                points: item.points,
                isInferred: item.isInferred,
                isActive: item.isActive,
                now: now
            )
        }
    }

    static func inferredPointChunks(
        from points: [LocationPoint],
        activeTrackingStart: Date? = nil,
        gapThreshold: TimeInterval = defaultGapThreshold
    ) -> [[LocationPoint]] {
        let sortedPoints = points.sorted { $0.timestamp < $1.timestamp }
        guard !sortedPoints.isEmpty else { return [] }

        var chunks: [[LocationPoint]] = []
        var currentChunk: [LocationPoint] = []
        currentChunk.reserveCapacity(sortedPoints.count)

        for point in sortedPoints {
            if let previous = currentChunk.last,
               shouldStartNewChunk(
                   previous: previous,
                   current: point,
                   activeTrackingStart: activeTrackingStart,
                   gapThreshold: gapThreshold
               ) {
                chunks.append(currentChunk)
                currentChunk = [point]
            } else {
                currentChunk.append(point)
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
    }

    static func totalDistance(in points: [LocationPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for index in 1..<points.count {
            total += points[index - 1].distance(to: points[index])
        }
        return total
    }

    private static func shouldStartNewChunk(
        previous: LocationPoint,
        current: LocationPoint,
        activeTrackingStart: Date?,
        gapThreshold: TimeInterval
    ) -> Bool {
        if let activeTrackingStart,
           previous.timestamp < activeTrackingStart,
           current.timestamp >= activeTrackingStart {
            return true
        }

        return current.timestamp.timeIntervalSince(previous.timestamp) > gapThreshold
    }

    private struct PendingSessionSummary {
        let id: String
        let storedSession: RecordingSession?
        let startedAt: Date
        let endedAt: Date?
        let points: [LocationPoint]
        let isInferred: Bool
        let isActive: Bool
    }
}

extension RecordingSession {
    static var preview: RecordingSession {
        RecordingSession(
            startedAt: Date().addingTimeInterval(-2 * 3600),
            endedAt: Date().addingTimeInterval(-20 * 60),
            customName: "Morning Errands"
        )
    }
}
