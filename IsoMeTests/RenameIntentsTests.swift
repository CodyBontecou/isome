import SwiftData
import XCTest
@testable import IsoMe

/// Tests for `RenameSupport` — rename visit / rename movement / rename the
/// active outing. All operations run against a throwaway in-memory container
/// mirroring `IntentSupport`'s schema; the on-disk store is never touched.
@MainActor
final class RenameIntentsTests: XCTestCase {
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

    // MARK: - Fixtures

    private func insertVisit(
        arrivedAt: Date = Date(),
        customName: String? = nil,
        updatedAt: Date? = nil
    ) throws -> Visit {
        let visit = Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: arrivedAt,
            customName: customName,
            updatedAt: updatedAt
        )
        context.insert(visit)
        try context.save()
        return visit
    }

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

    /// Re-fetches through a FRESH context so assertions prove persistence
    /// (post-save), not just the writing context's cache.
    private func fetchFreshVisit(id: UUID) throws -> Visit? {
        let fresh = ModelContext(container)
        var descriptor = FetchDescriptor<Visit>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try fresh.fetch(descriptor).first
    }

    private func fetchFreshSession(id: UUID) throws -> RecordingSession? {
        let fresh = ModelContext(container)
        var descriptor = FetchDescriptor<RecordingSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try fresh.fetch(descriptor).first
    }

    // MARK: - rename(visitWith:to:context:)

    func testRenameVisitPersistsCustomNameAndSetsUpdatedAt() throws {
        let visit = try insertVisit(customName: nil, updatedAt: nil)

        let entity = try RenameSupport.rename(visitWith: visit.id, to: "Gym", context: context)

        let stored = try XCTUnwrap(try fetchFreshVisit(id: visit.id))
        XCTAssertEqual(stored.customName, "Gym")
        XCTAssertNotNil(stored.updatedAt, "updatedAt should be stamped on rename (was nil before)")

        XCTAssertEqual(entity.id, visit.id)
        XCTAssertEqual(entity.customName, "Gym")
        XCTAssertEqual(entity.name, "Gym")
    }

    func testRenameVisitOverwritesExistingCustomName() throws {
        let visit = try insertVisit(customName: "Old Name", updatedAt: Date.distantPast)

        _ = try RenameSupport.rename(visitWith: visit.id, to: "New Name", context: context)

        let stored = try XCTUnwrap(try fetchFreshVisit(id: visit.id))
        XCTAssertEqual(stored.customName, "New Name")
        XCTAssertGreaterThan(try XCTUnwrap(stored.updatedAt), Date.distantPast)
    }

    func testRenameVisitDoesNotTouchOtherVisits() throws {
        let target = try insertVisit(customName: nil)
        let bystander = try insertVisit(customName: "Keep Me")

        _ = try RenameSupport.rename(visitWith: target.id, to: "Renamed", context: context)

        XCTAssertEqual(try fetchFreshVisit(id: bystander.id)?.customName, "Keep Me")
    }

    // MARK: - rename(sessionWith:to:context:)

    func testRenameSessionPersistsCustomName() throws {
        let session = try insertSession(
            startedAt: Date().addingTimeInterval(-3_600),
            endedAt: Date(),
            customName: nil
        )

        let entity = try RenameSupport.rename(sessionWith: session.id, to: "Morning Run", context: context)

        let stored = try XCTUnwrap(try fetchFreshSession(id: session.id))
        XCTAssertEqual(stored.customName, "Morning Run")

        XCTAssertEqual(entity.id, session.id)
        XCTAssertEqual(entity.customName, "Morning Run")
        XCTAssertEqual(entity.name, "Morning Run")
    }

    func testRenameSessionOverwritesExistingCustomName() throws {
        let session = try insertSession(startedAt: Date(), customName: "Old Outing")

        _ = try RenameSupport.rename(sessionWith: session.id, to: "New Outing", context: context)

        XCTAssertEqual(try fetchFreshSession(id: session.id)?.customName, "New Outing")
    }

    // MARK: - Empty names

    func testRenameVisitWithEmptyNameThrowsAndWritesNothing() throws {
        let visit = try insertVisit(customName: nil, updatedAt: nil)

        XCTAssertThrowsError(try RenameSupport.rename(visitWith: visit.id, to: "", context: context)) { error in
            guard case IsoMeIntentError.emptyName = error else {
                return XCTFail("Expected emptyName, got \(error)")
            }
        }

        let stored = try XCTUnwrap(try fetchFreshVisit(id: visit.id))
        XCTAssertNil(stored.customName, "nothing should be written when the name is empty")
        XCTAssertNil(stored.updatedAt)
    }

    func testRenameVisitWithWhitespaceOnlyNameThrows() throws {
        let visit = try insertVisit(customName: nil)

        XCTAssertThrowsError(try RenameSupport.rename(visitWith: visit.id, to: "   \n\t ", context: context)) { error in
            guard case IsoMeIntentError.emptyName = error else {
                return XCTFail("Expected emptyName, got \(error)")
            }
        }

        XCTAssertNil(try fetchFreshVisit(id: visit.id)?.customName)
    }

    func testRenameSessionWithEmptyNameThrowsAndWritesNothing() throws {
        let session = try insertSession(startedAt: Date(), customName: nil)

        XCTAssertThrowsError(try RenameSupport.rename(sessionWith: session.id, to: "   ", context: context)) { error in
            guard case IsoMeIntentError.emptyName = error else {
                return XCTFail("Expected emptyName, got \(error)")
            }
        }

        XCTAssertNil(try fetchFreshSession(id: session.id)?.customName)
    }

    // MARK: - Unknown ids

    func testRenameVisitWithUnknownIdThrowsItemNotFound() throws {
        _ = try insertVisit(customName: nil)

        XCTAssertThrowsError(try RenameSupport.rename(visitWith: UUID(), to: "Gym", context: context)) { error in
            guard case IsoMeIntentError.itemNotFound = error else {
                return XCTFail("Expected itemNotFound, got \(error)")
            }
        }
    }

    func testRenameSessionWithUnknownIdThrowsItemNotFound() throws {
        _ = try insertSession(startedAt: Date())

        XCTAssertThrowsError(try RenameSupport.rename(sessionWith: UUID(), to: "Run", context: context)) { error in
            guard case IsoMeIntentError.itemNotFound = error else {
                return XCTFail("Expected itemNotFound, got \(error)")
            }
        }
    }

    // MARK: - renameActiveSession(to:context:)

    func testRenameActiveSessionRenamesTheOpenSession() throws {
        let ended = try insertSession(
            startedAt: Date().addingTimeInterval(-7_200),
            endedAt: Date().addingTimeInterval(-3_600),
            customName: "Closed Outing"
        )
        let active = try insertSession(startedAt: Date(), customName: nil)

        let returned = try RenameSupport.renameActiveSession(to: "Live Outing", context: context)

        XCTAssertEqual(returned, "Live Outing")
        XCTAssertEqual(try fetchFreshSession(id: active.id)?.customName, "Live Outing")
        XCTAssertEqual(try fetchFreshSession(id: ended.id)?.customName, "Closed Outing", "ended sessions are untouched")
    }

    func testRenameActiveSessionThrowsNoActiveOutingWhenNoneOpen() throws {
        _ = try insertSession(startedAt: Date().addingTimeInterval(-3_600), endedAt: Date())

        XCTAssertThrowsError(try RenameSupport.renameActiveSession(to: "Anything", context: context)) { error in
            guard case IsoMeIntentError.noActiveOuting = error else {
                return XCTFail("Expected noActiveOuting, got \(error)")
            }
        }
    }

    func testRenameActiveSessionThrowsNoActiveOutingOnEmptyStore() throws {
        XCTAssertThrowsError(try RenameSupport.renameActiveSession(to: "Anything", context: context)) { error in
            guard case IsoMeIntentError.noActiveOuting = error else {
                return XCTFail("Expected noActiveOuting, got \(error)")
            }
        }
    }

    func testRenameActiveSessionRejectsWhitespaceNameWithOutingSpecificError() throws {
        // Behavior preservation: the extracted RenameCurrentOutingIntent logic
        // keeps throwing emptyOutingName (not the generic emptyName) so the
        // Siri error wording stays identical to the pre-extraction intent.
        let active = try insertSession(startedAt: Date(), customName: nil)

        XCTAssertThrowsError(try RenameSupport.renameActiveSession(to: "   \n\t ", context: context)) { error in
            guard case IsoMeIntentError.emptyOutingName = error else {
                return XCTFail("Expected emptyOutingName, got \(error)")
            }
        }

        XCTAssertNil(try fetchFreshSession(id: active.id)?.customName, "nothing should be written for an empty name")
    }

    func testRenameActiveSessionPicksNewestWhenMultipleOpen() throws {
        // Defensive: mirrors the fetch's reverse-sort + fetchLimit 1 behavior.
        let older = try insertSession(startedAt: Date().addingTimeInterval(-600), customName: nil)
        let newer = try insertSession(startedAt: Date().addingTimeInterval(-60), customName: nil)

        _ = try RenameSupport.renameActiveSession(to: "Newest Wins", context: context)

        XCTAssertEqual(try fetchFreshSession(id: newer.id)?.customName, "Newest Wins")
        XCTAssertNil(try fetchFreshSession(id: older.id)?.customName)
    }

    // MARK: - Trimming

    func testRenameVisitTrimsSurroundingWhitespaceBeforePersisting() throws {
        let visit = try insertVisit(customName: nil)

        let entity = try RenameSupport.rename(visitWith: visit.id, to: "  Blue Bottle  ", context: context)

        XCTAssertEqual(try fetchFreshVisit(id: visit.id)?.customName, "Blue Bottle")
        XCTAssertEqual(entity.name, "Blue Bottle")
    }

    func testRenameSessionTrimsSurroundingWhitespaceBeforePersisting() throws {
        let session = try insertSession(startedAt: Date())

        let entity = try RenameSupport.rename(sessionWith: session.id, to: "\tMorning Run\n", context: context)

        XCTAssertEqual(try fetchFreshSession(id: session.id)?.customName, "Morning Run")
        XCTAssertEqual(entity.name, "Morning Run")
    }

    func testRenameActiveSessionTrimsSurroundingWhitespace() throws {
        let active = try insertSession(startedAt: Date())

        let returned = try RenameSupport.renameActiveSession(to: "  Padded Name  ", context: context)

        XCTAssertEqual(returned, "Padded Name")
        XCTAssertEqual(try fetchFreshSession(id: active.id)?.customName, "Padded Name")
    }
}
