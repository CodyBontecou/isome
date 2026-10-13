import SwiftData
import XCTest
@testable import IsoMe

/// Tests for `VisitQuery` / `MovementQuery` fetch helpers and entity name
/// fallbacks. All fetches run against a throwaway in-memory container — the
/// on-disk store is never touched.
@MainActor
final class IsoMeEntityQueryTests: XCTestCase {
    // MARK: - Fixtures

    /// Mirrors `IntentSupport`'s schema, in memory only.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Visit.self,
            LocationPoint.self,
            RecordingSession.self,
            PhotoMoment.self,
            SavedPlace.self, CountryStay.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func insertVisits(arrivedAtDates: [Date], into context: ModelContext) throws -> [Visit] {
        let visits = arrivedAtDates.map { date in
            Visit(latitude: 37.7749, longitude: -122.4194, arrivedAt: date)
        }
        visits.forEach(context.insert)
        try context.save()
        return visits
    }

    private func insertSessions(startedAtDates: [Date], into context: ModelContext) throws -> [RecordingSession] {
        let sessions = startedAtDates.map { date in
            RecordingSession(startedAt: date)
        }
        sessions.forEach(context.insert)
        try context.save()
        return sessions
    }

    // MARK: - suggestedEntities: recency ordering + limit

    func testVisitFetchRecentOrdersByArrivedAtDescendingAndLimits() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try insertVisits(
            arrivedAtDates: (0..<25).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let entities = try VisitQuery.fetchRecent(context: context, limit: 20)

        XCTAssertEqual(entities.count, 20)
        let timestamps = entities.map(\.arrivedAt)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >), "expected newest-first ordering")
        XCTAssertEqual(timestamps.first, base.addingTimeInterval(24 * 3600), "expected the newest visit first")
    }

    func testMovementFetchRecentOrdersByStartedAtDescendingAndLimits() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try insertSessions(
            startedAtDates: (0..<25).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let entities = try MovementQuery.fetchRecent(context: context, limit: 20)

        XCTAssertEqual(entities.count, 20)
        let timestamps = entities.map(\.startedAt)
        XCTAssertEqual(timestamps, timestamps.sorted(by: >), "expected newest-first ordering")
        XCTAssertEqual(timestamps.first, base.addingTimeInterval(24 * 3600), "expected the newest session first")
    }

    // MARK: - entities(for:) resolution

    func testVisitFetchByIdentifiersResolvesSubset() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let visits = try insertVisits(
            arrivedAtDates: [base, base.addingTimeInterval(60), base.addingTimeInterval(120)],
            into: context
        )

        let wanted: Set<UUID> = [visits[0].id, visits[2].id]
        let entities = try VisitQuery.fetch(context: context, identifiers: Array(wanted))

        XCTAssertEqual(Set(entities.map(\.id)), wanted)
        XCTAssertEqual(entities.count, 2)
    }

    func testMovementFetchByIdentifiersResolvesSubset() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = try insertSessions(
            startedAtDates: [base, base.addingTimeInterval(60), base.addingTimeInterval(120)],
            into: context
        )

        let wanted: Set<UUID> = [sessions[0].id, sessions[2].id]
        let entities = try MovementQuery.fetch(context: context, identifiers: Array(wanted))

        XCTAssertEqual(Set(entities.map(\.id)), wanted)
        XCTAssertEqual(entities.count, 2)
    }

    // MARK: - Name fallback chains

    func testVisitEntityNameFallbackChain() {
        XCTAssertEqual(VisitEntity.displayName(customName: " Gym ", locationName: nil, address: nil), "Gym")
        XCTAssertEqual(
            VisitEntity.displayName(customName: "   ", locationName: "Blue Bottle", address: "123 Main St"),
            "Blue Bottle",
            "whitespace-only customName should be skipped"
        )
        XCTAssertEqual(
            VisitEntity.displayName(customName: nil, locationName: nil, address: "123 Main St"),
            "123 Main St"
        )
        XCTAssertEqual(
            VisitEntity.displayName(customName: nil, locationName: nil, address: "   "),
            "Visit",
            "whitespace-only address should fall through to the last resort"
        )
    }

    func testMovementEntityNameFallbackChain() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(MovementEntity.displayName(customName: " Morning Run ", startedAt: startedAt), "Morning Run")

        let expectedFormatter = DateFormatter()
        expectedFormatter.dateStyle = .medium
        expectedFormatter.timeStyle = .none
        XCTAssertEqual(
            MovementEntity.displayName(customName: "\t\n ", startedAt: startedAt),
            expectedFormatter.string(from: startedAt),
            "whitespace-only customName should fall back to the medium-style start date"
        )
        XCTAssertEqual(
            MovementEntity.displayName(customName: nil, startedAt: startedAt),
            expectedFormatter.string(from: startedAt)
        )
    }

    // MARK: - Date-window helpers (for the cycle-2 date-range conformance)

    func testVisitFetchArrivedWithinFiltersToWindow() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-10 * 86400),
                base.addingTimeInterval(-2 * 86400),
                base.addingTimeInterval(-0.5 * 86400),
            ],
            into: context
        )

        let window = base.addingTimeInterval(-7 * 86400)...base
        let entities = try VisitQuery.fetch(context: context, arrivedWithin: window)

        XCTAssertEqual(Set(entities.map(\.id)), Set([inserted[1].id, inserted[2].id]))
        XCTAssertEqual(entities.map(\.id), [inserted[2].id, inserted[1].id], "expected newest-first ordering")
    }

    func testMovementFetchStartedWithinFiltersToWindow() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertSessions(
            startedAtDates: [
                base.addingTimeInterval(-10 * 86400),
                base.addingTimeInterval(-2 * 86400),
                base.addingTimeInterval(-0.5 * 86400),
            ],
            into: context
        )

        let window = base.addingTimeInterval(-7 * 86400)...base
        let entities = try MovementQuery.fetch(context: context, startedWithin: window)

        XCTAssertEqual(Set(entities.map(\.id)), Set([inserted[1].id, inserted[2].id]))
        XCTAssertEqual(entities.map(\.id), [inserted[2].id, inserted[1].id], "expected newest-first ordering")
    }

    // MARK: - DateWindow comparator semantics (EntityPropertyQuery cycle-2)

    func testDateWindowComparatorBounds() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(DateWindow.after(base).contains(base.addingTimeInterval(1)))
        XCTAssertFalse(DateWindow.after(base).contains(base), "after is strictly greater")
        XCTAssertTrue(DateWindow.before(base).contains(base.addingTimeInterval(-1)))
        XCTAssertFalse(DateWindow.before(base).contains(base), "before is strictly less")
        XCTAssertTrue(
            DateWindow.between(base, base.addingTimeInterval(10)).contains(base),
            "between lower bound is inclusive"
        )
        XCTAssertTrue(
            DateWindow.between(base, base.addingTimeInterval(10)).contains(base.addingTimeInterval(10)),
            "between upper bound is inclusive"
        )
        XCTAssertFalse(DateWindow.between(base, base.addingTimeInterval(10)).contains(base.addingTimeInterval(11)))
    }

    func testDateWindowWidenedIntersectionFoldsComparators() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertNil(
            DateWindow.widenedIntersection(of: [.after(base), .before(base.addingTimeInterval(-10))]),
            "mutually exclusive comparators fold to an impossible window"
        )
        XCTAssertEqual(
            DateWindow.widenedIntersection(of: [
                .after(base.addingTimeInterval(-3600)),
                .before(base.addingTimeInterval(3600)),
                .between(base.addingTimeInterval(-7200), base.addingTimeInterval(7200)),
            ]),
            base.addingTimeInterval(-3600)...base.addingTimeInterval(3600),
            "the tightest bounds win the fold"
        )
        XCTAssertEqual(
            DateWindow.widenedIntersection(of: [.between(base, base)]),
            base...base,
            "a single-point between survives the fold"
        )
    }

    // MARK: - Comparator mapping against staggered fixtures

    func testVisitFetchMatchingAfterIsStrictlyAfter() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-2 * 86400),
                base,
                base.addingTimeInterval(86400),
                base.addingTimeInterval(2 * 86400),
            ],
            into: context
        )

        let entities = try VisitQuery.fetch(context: context, matching: [.after(base)], mode: .and, dateOrder: nil, limit: nil)

        XCTAssertEqual(
            Set(entities.map(\.id)),
            Set([inserted[2].id, inserted[3].id]),
            "the visit exactly at the bound must be excluded (strict after)"
        )
        XCTAssertEqual(entities.map(\.id), [inserted[3].id, inserted[2].id], "default order is newest-first")
    }

    func testVisitFetchMatchingBeforeIsStrictlyBefore() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-2 * 86400),
                base,
                base.addingTimeInterval(86400),
            ],
            into: context
        )

        let entities = try VisitQuery.fetch(context: context, matching: [.before(base)], mode: .and, dateOrder: nil, limit: nil)

        XCTAssertEqual(
            Set(entities.map(\.id)),
            Set([inserted[0].id]),
            "the visit exactly at the bound must be excluded (strict before)"
        )
    }

    func testVisitFetchMatchingBetweenIsInclusive() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-86400),
                base,
                base.addingTimeInterval(86400),
                base.addingTimeInterval(2 * 86400),
            ],
            into: context
        )

        let entities = try VisitQuery.fetch(
            context: context,
            matching: [.between(base, base.addingTimeInterval(2 * 86400))],
            mode: .and,
            dateOrder: nil,
            limit: nil
        )

        XCTAssertEqual(
            Set(entities.map(\.id)),
            Set([inserted[1].id, inserted[2].id, inserted[3].id]),
            "both between bounds are inclusive; the outside visit is dropped"
        )
    }

    func testMovementFetchMatchingAfterBeforeAndBetween() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertSessions(
            startedAtDates: [
                base.addingTimeInterval(-2 * 86400),
                base,
                base.addingTimeInterval(86400),
                base.addingTimeInterval(2 * 86400),
            ],
            into: context
        )

        let after = try MovementQuery.fetch(context: context, matching: [.after(base)], mode: .and, dateOrder: nil, limit: nil)
        XCTAssertEqual(Set(after.map(\.id)), Set([inserted[2].id, inserted[3].id]), "strict after")

        let before = try MovementQuery.fetch(context: context, matching: [.before(base)], mode: .and, dateOrder: nil, limit: nil)
        XCTAssertEqual(Set(before.map(\.id)), Set([inserted[0].id]), "strict before")

        let between = try MovementQuery.fetch(
            context: context,
            matching: [.between(base, base.addingTimeInterval(2 * 86400))],
            mode: .and,
            dateOrder: nil,
            limit: nil
        )
        XCTAssertEqual(
            Set(between.map(\.id)),
            Set([inserted[1].id, inserted[2].id, inserted[3].id]),
            "inclusive between"
        )
    }

    // MARK: - Comparator modes

    func testVisitFetchMatchingAndModeIntersectsComparators() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-86400),
                base,
                base.addingTimeInterval(86400),
                base.addingTimeInterval(2 * 86400),
                base.addingTimeInterval(3 * 86400),
            ],
            into: context
        )

        // after(base) AND before(base + 2d): strict intersection — the visits
        // exactly on either bound are excluded, only the middle one survives.
        let entities = try VisitQuery.fetch(
            context: context,
            matching: [.after(base), .before(base.addingTimeInterval(2 * 86400))],
            mode: .and,
            dateOrder: nil,
            limit: nil
        )

        XCTAssertEqual(entities.map(\.id), [inserted[2].id])
    }

    func testVisitFetchMatchingMutuallyExclusiveComparatorsReturnEmpty() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        try insertVisits(
            arrivedAtDates: [base.addingTimeInterval(-86400), base, base.addingTimeInterval(86400)],
            into: context
        )

        let entities = try VisitQuery.fetch(
            context: context,
            matching: [.after(base.addingTimeInterval(86400)), .before(base.addingTimeInterval(-86400))],
            mode: .and,
            dateOrder: nil,
            limit: nil
        )

        XCTAssertEqual(entities.count, 0, "impossible window must not crash ClosedRange construction")
    }

    func testVisitFetchMatchingOrModeUnionsWindowsAndDeduplicates() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-2 * 86400),
                base.addingTimeInterval(-86400),
                base,
                base.addingTimeInterval(86400),
                base.addingTimeInterval(2 * 86400),
            ],
            into: context
        )

        // before(-1d) OR between(-2d, +2d) OR after(+1d): every visit matches at
        // least one comparator, several match two — none may appear twice.
        let entities = try VisitQuery.fetch(
            context: context,
            matching: [
                .before(base.addingTimeInterval(-86400)),
                .between(base.addingTimeInterval(-2 * 86400), base.addingTimeInterval(2 * 86400)),
                .after(base.addingTimeInterval(86400)),
            ],
            mode: .or,
            dateOrder: nil,
            limit: nil
        )

        XCTAssertEqual(entities.count, 5, "overlapping windows must not duplicate entities")
        XCTAssertEqual(Set(entities.map(\.id)), Set(inserted.map(\.id)))
        XCTAssertEqual(entities.map(\.id), inserted.reversed().map(\.id), "default order is newest-first")
    }

    func testVisitFetchMatchingOrModeRefinesStrictBounds() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: [
                base.addingTimeInterval(-2 * 86400),
                base.addingTimeInterval(-86400),
                base,
                base.addingTimeInterval(86400),
                base.addingTimeInterval(2 * 86400),
            ],
            into: context
        )

        // before(-1d) OR after(+1d): the widened windows would admit the visits
        // exactly on the bounds; strict semantics must drop them.
        let entities = try VisitQuery.fetch(
            context: context,
            matching: [
                .before(base.addingTimeInterval(-86400)),
                .after(base.addingTimeInterval(86400)),
            ],
            mode: .or,
            dateOrder: nil,
            limit: nil
        )

        XCTAssertEqual(Set(entities.map(\.id)), Set([inserted[0].id, inserted[4].id]))
    }

    // MARK: - Sort direction and limit

    func testVisitFetchMatchingAppliesSortDirectionAndLimit() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: (0..<5).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let ascending = try VisitQuery.fetch(context: context, matching: [], mode: .and, dateOrder: .ascending, limit: nil)
        XCTAssertEqual(ascending.map(\.id), inserted.map(\.id), "ascending order is oldest-first")

        let descending = try VisitQuery.fetch(context: context, matching: [], mode: .and, dateOrder: .descending, limit: nil)
        XCTAssertEqual(descending.map(\.id), inserted.reversed().map(\.id), "descending order is newest-first")

        let defaultOrder = try VisitQuery.fetch(context: context, matching: [], mode: .and, dateOrder: nil, limit: nil)
        XCTAssertEqual(defaultOrder.map(\.id), inserted.reversed().map(\.id), "nil order defaults to newest-first")

        let limitedAscending = try VisitQuery.fetch(context: context, matching: [], mode: .and, dateOrder: .ascending, limit: 2)
        XCTAssertEqual(limitedAscending.map(\.id), [inserted[0].id, inserted[1].id], "limit applies after the ascending sort")

        let limitedDefault = try VisitQuery.fetch(context: context, matching: [], mode: .and, dateOrder: nil, limit: 2)
        XCTAssertEqual(limitedDefault.map(\.id), [inserted[4].id, inserted[3].id], "limit applies after the default newest-first sort")
    }

    func testVisitFetchMatchingLimitAppliesWithinWindow() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertVisits(
            arrivedAtDates: (0..<4).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let entities = try VisitQuery.fetch(
            context: context,
            matching: [.after(base.addingTimeInterval(-1800))],
            mode: .and,
            dateOrder: nil,
            limit: 2
        )

        XCTAssertEqual(entities.map(\.id), [inserted[3].id, inserted[2].id], "limit keeps the newest within the window")
    }

    func testMovementFetchMatchingAppliesSortDirectionAndLimit() throws {
        let context = try makeContext()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let inserted = try insertSessions(
            startedAtDates: (0..<4).map { base.addingTimeInterval(TimeInterval($0) * 3600) },
            into: context
        )

        let ascending = try MovementQuery.fetch(context: context, matching: [], mode: .and, dateOrder: .ascending, limit: nil)
        XCTAssertEqual(ascending.map(\.id), inserted.map(\.id), "ascending order is oldest-first")

        let newestFirst = try MovementQuery.fetch(context: context, matching: [], mode: .and, dateOrder: nil, limit: 2)
        XCTAssertEqual(newestFirst.map(\.id), [inserted[3].id, inserted[2].id], "default order newest-first, limited to two")
    }

    // MARK: - Empty store

    func testEmptyStoreReturnsEmptyResultsWithoutCrashing() throws {
        let context = try makeContext()

        XCTAssertEqual(try VisitQuery.fetchRecent(context: context, limit: 20).count, 0)
        XCTAssertEqual(try MovementQuery.fetchRecent(context: context, limit: 20).count, 0)
        XCTAssertEqual(try VisitQuery.fetch(context: context, identifiers: [UUID()]).count, 0)
        XCTAssertEqual(try MovementQuery.fetch(context: context, identifiers: [UUID()]).count, 0)
        XCTAssertEqual(try VisitQuery.fetch(context: context, arrivedWithin: Date.distantPast...Date.distantFuture).count, 0)
        XCTAssertEqual(try MovementQuery.fetch(context: context, startedWithin: Date.distantPast...Date.distantFuture).count, 0)
    }
}
