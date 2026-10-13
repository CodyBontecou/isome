import SwiftData
import XCTest
@testable import IsoMe

/// Tests for `GetVisitsIntent` / `GetMovementsIntent`.
///
/// `perform()` reads through `IntentSupport.makeContext()` — the on-disk store
/// — so it is deliberately not executed here. Instead, these tests compose the
/// exact seams `perform()` uses, against an in-memory container:
///   1. `ExportDataParameterResolution.dateRange(start:end:now:)` — parameter
///      defaulting (nil → today) and the inverted-dates error path, asserted
///      directly on the shared resolver,
///   2. `VisitQuery.fetch(context:arrivedWithin:)` /
///      `MovementQuery.fetch(context:startedWithin:)` — range filtering,
///      newest-first ordering, and id/name entity mapping,
///   3. `ReadIntentsDialogs` — the 0 / 1 / N count wording.
@MainActor
final class GetVisitsGetMovementsIntentTests: XCTestCase {
    // MARK: - Fixtures

    /// Fixed noon so the "today" window is deterministic regardless of when
    /// the suite runs; `startOfDay` still uses `Calendar.current`, so the
    /// midnight-straddling fixtures below stay timezone-agnostic.
    private static let fixedNoon = Date(timeIntervalSince1970: 1_778_414_400) // 2026-05-10T12:00:00Z

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        // In-memory store mirroring IntentSupport's schema — never the on-disk store.
        let schema = Schema([
            Visit.self,
            LocationPoint.self,
            RecordingSession.self,
            PhotoMoment.self,
            SavedPlace.self, CountryStay.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    @discardableResult
    private func insertVisit(
        arrivedAt: Date,
        customName: String? = nil,
        locationName: String? = nil,
        address: String? = nil
    ) throws -> Visit {
        let visit = Visit(
            latitude: 37.776502,
            longitude: -122.424098,
            arrivedAt: arrivedAt,
            customName: customName,
            locationName: locationName,
            address: address
        )
        context.insert(visit)
        try context.save()
        return visit
    }

    @discardableResult
    private func insertSession(
        startedAt: Date,
        endedAt: Date? = nil,
        customName: String? = nil
    ) throws -> RecordingSession {
        let session = RecordingSession(
            startedAt: startedAt,
            endedAt: endedAt,
            customName: customName
        )
        context.insert(session)
        try context.save()
        return session
    }

    /// Renders the count-summary text the way Siri/Shortcuts would resolve it,
    /// so the 0 / 1 / N wording can be asserted without running an intent.
    /// (`IntentDialog` itself is opaque in the SDK, so the seam builders return
    /// `LocalizedStringResource` and `perform()` wraps them in an
    /// `IntentDialog` at the boundary.)
    private func render(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    // MARK: - Default (nil) parameters → today's window

    func testDefaultNilParametersExcludeVisitsFromBeforeMidnight() throws {
        let now = Self.fixedNoon
        let startOfToday = Calendar.current.startOfDay(for: now)
        let yesterdaysVisit = try insertVisit(
            arrivedAt: startOfToday.addingTimeInterval(-3_600),
            customName: "Yesterday Nightcap"
        )
        let firstToday = try insertVisit(arrivedAt: startOfToday.addingTimeInterval(60), customName: "First Today")
        let latestToday = try insertVisit(arrivedAt: now.addingTimeInterval(-60), customName: "Just Before Now")

        let range = try ExportDataParameterResolution.dateRange(start: nil, end: nil, now: now)
        let entities = try VisitQuery.fetch(context: context, arrivedWithin: range)

        XCTAssertEqual(entities.map(\.id), [latestToday.id, firstToday.id], "today's visits only, newest first")
        XCTAssertFalse(entities.map(\.id).contains(yesterdaysVisit.id), "yesterday's visit must be excluded")
    }

    func testDefaultNilParametersExcludeMovementsFromBeforeMidnight() throws {
        let now = Self.fixedNoon
        let startOfToday = Calendar.current.startOfDay(for: now)
        let yesterdaysMovement = try insertSession(
            startedAt: startOfToday.addingTimeInterval(-3_600),
            endedAt: startOfToday.addingTimeInterval(-600),
            customName: "Yesterday Walk"
        )
        let firstToday = try insertSession(startedAt: startOfToday.addingTimeInterval(120), customName: "Morning Run")
        let latestToday = try insertSession(startedAt: now.addingTimeInterval(-120))

        let range = try ExportDataParameterResolution.dateRange(start: nil, end: nil, now: now)
        let entities = try MovementQuery.fetch(context: context, startedWithin: range)

        XCTAssertEqual(entities.map(\.id), [latestToday.id, firstToday.id], "today's movements only, newest first")
        XCTAssertFalse(entities.map(\.id).contains(yesterdaysMovement.id), "yesterday's movement must be excluded")
    }

    // MARK: - Explicit start/end range filtering

    func testExplicitRangeFiltersVisitsByArrivedAt() throws {
        let now = Self.fixedNoon
        let beforeWindow = try insertVisit(arrivedAt: now.addingTimeInterval(-10 * 86_400), customName: "Ten Days Ago")
        let olderInRange = try insertVisit(arrivedAt: now.addingTimeInterval(-7_200), customName: "Older In Range")
        let newerInRange = try insertVisit(arrivedAt: now.addingTimeInterval(-60), customName: "Newer In Range")
        let afterWindow = try insertVisit(arrivedAt: now.addingTimeInterval(86_400), customName: "Tomorrow")

        let range = now.addingTimeInterval(-86_400)...now
        let entities = try VisitQuery.fetch(context: context, arrivedWithin: range)

        XCTAssertEqual(entities.map(\.id), [newerInRange.id, olderInRange.id], "window-filtered, newest first")
        XCTAssertFalse(entities.map(\.id).contains(beforeWindow.id))
        XCTAssertFalse(entities.map(\.id).contains(afterWindow.id))
    }

    func testExplicitRangeFiltersMovementsByStartedAt() throws {
        let now = Self.fixedNoon
        let beforeWindow = try insertSession(
            startedAt: now.addingTimeInterval(-10 * 86_400),
            endedAt: now.addingTimeInterval(-9 * 86_400),
            customName: "Ten Days Ago"
        )
        let olderInRange = try insertSession(startedAt: now.addingTimeInterval(-7_200), endedAt: now.addingTimeInterval(-3_600), customName: "Older In Range")
        let newerInRange = try insertSession(startedAt: now.addingTimeInterval(-60), customName: "Newer In Range")
        let afterWindow = try insertSession(startedAt: now.addingTimeInterval(86_400), customName: "Tomorrow")

        let range = now.addingTimeInterval(-86_400)...now
        let entities = try MovementQuery.fetch(context: context, startedWithin: range)

        XCTAssertEqual(entities.map(\.id), [newerInRange.id, olderInRange.id], "window-filtered, newest first")
        XCTAssertFalse(entities.map(\.id).contains(beforeWindow.id))
        XCTAssertFalse(entities.map(\.id).contains(afterWindow.id))
    }

    func testRangeBoundsAreInclusive() throws {
        let now = Self.fixedNoon
        let lower = now.addingTimeInterval(-3_600)
        let visitAtLower = try insertVisit(arrivedAt: lower, customName: "At Lower Bound")
        let visitAtUpper = try insertVisit(arrivedAt: now, customName: "At Upper Bound")
        let movementAtLower = try insertSession(startedAt: lower, endedAt: now, customName: "At Lower Bound")
        let movementAtUpper = try insertSession(startedAt: now, customName: "At Upper Bound")

        let range = lower...now
        XCTAssertEqual(
            Set(try VisitQuery.fetch(context: context, arrivedWithin: range).map(\.id)),
            Set([visitAtLower.id, visitAtUpper.id])
        )
        XCTAssertEqual(
            Set(try MovementQuery.fetch(context: context, startedWithin: range).map(\.id)),
            Set([movementAtLower.id, movementAtUpper.id])
        )
    }

    // MARK: - Entity mapping: id + name fallback chains

    func testReturnedVisitEntitiesCarryIdAndNameFallbackChain() throws {
        let now = Self.fixedNoon
        let custom = try insertVisit(arrivedAt: now.addingTimeInterval(-600), customName: "  Gym  ")
        let byLocation = try insertVisit(arrivedAt: now.addingTimeInterval(-1_200), locationName: "Blue Bottle")
        let byAddress = try insertVisit(arrivedAt: now.addingTimeInterval(-1_800), address: "123 Main St")
        let lastResort = try insertVisit(arrivedAt: now.addingTimeInterval(-2_400))

        let range = now.addingTimeInterval(-86_400)...now
        let entities = try VisitQuery.fetch(context: context, arrivedWithin: range)
        let namesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0.name) })

        XCTAssertEqual(namesById[custom.id], "Gym", "custom name wins, trimmed")
        XCTAssertEqual(namesById[byLocation.id], "Blue Bottle", "location name is the first fallback")
        XCTAssertEqual(namesById[byAddress.id], "123 Main St", "address is the second fallback")
        XCTAssertEqual(namesById[lastResort.id], "Visit", "last resort")
    }

    func testReturnedMovementEntitiesCarryIdAndNameFallbackChain() throws {
        let now = Self.fixedNoon
        let custom = try insertSession(startedAt: now.addingTimeInterval(-600), customName: " Morning Run ")
        let unnamedStartedAt = Date(timeIntervalSince1970: 1_760_000_000)
        let unnamed = try insertSession(
            startedAt: unnamedStartedAt,
            endedAt: unnamedStartedAt.addingTimeInterval(1_800)
        )

        let range = unnamedStartedAt...now
        let entities = try MovementQuery.fetch(context: context, startedWithin: range)
        let namesById = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0.name) })

        XCTAssertEqual(namesById[custom.id], "Morning Run", "custom name wins, trimmed")

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        XCTAssertEqual(
            namesById[unnamed.id],
            formatter.string(from: unnamedStartedAt),
            "unnamed movements fall back to their medium-style start date"
        )
    }

    // MARK: - Count dialog wording (0 / 1 / N)

    func testVisitCountDialogWording() {
        XCTAssertEqual(render(ReadIntentsDialogs.visitCount(0)), "No visits found.")
        XCTAssertEqual(render(ReadIntentsDialogs.visitCount(1)), "1 visit found.")
        XCTAssertEqual(render(ReadIntentsDialogs.visitCount(7)), "7 visits found.")
    }

    func testMovementCountDialogWording() {
        XCTAssertEqual(render(ReadIntentsDialogs.movementCount(0)), "No movements found.")
        XCTAssertEqual(render(ReadIntentsDialogs.movementCount(1)), "1 movement found.")
        XCTAssertEqual(render(ReadIntentsDialogs.movementCount(12)), "12 movements found.")
    }

    // MARK: - Empty store composes to the 0-count dialogs

    func testEmptyStoreComposesToZeroCountDialogs() throws {
        let now = Self.fixedNoon
        let range = try ExportDataParameterResolution.dateRange(start: nil, end: nil, now: now)

        let visits = try VisitQuery.fetch(context: context, arrivedWithin: range)
        XCTAssertEqual(visits.count, 0)
        XCTAssertEqual(render(ReadIntentsDialogs.visitCount(visits.count)), "No visits found.")

        let movements = try MovementQuery.fetch(context: context, startedWithin: range)
        XCTAssertEqual(movements.count, 0)
        XCTAssertEqual(render(ReadIntentsDialogs.movementCount(movements.count)), "No movements found.")
    }

    // MARK: - Inverted parameters

    /// `perform()` passes its parameters straight into the shared resolver
    /// with no error handling of its own, so the throw is asserted on the
    /// resolver directly — running `perform()` would open the on-disk store.
    func testInvertedDateParametersThrowInvalidDateRange() {
        let later = Self.fixedNoon
        let earlier = Self.fixedNoon.addingTimeInterval(-86_400)

        XCTAssertThrowsError(
            try ExportDataParameterResolution.dateRange(start: later, end: earlier, now: Self.fixedNoon)
        ) { error in
            guard case IsoMeIntentError.invalidDateRange = error else {
                return XCTFail("Expected invalidDateRange, got \(error)")
            }
        }
    }
}
