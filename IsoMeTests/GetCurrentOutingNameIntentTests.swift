import SwiftData
import XCTest
@testable import IsoMe

@MainActor
final class GetCurrentOutingNameIntentTests: XCTestCase {
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

    private func insertSession(
        startedAt: Date,
        endedAt: Date? = nil,
        customName: String? = nil
    ) throws {
        let session = RecordingSession(
            startedAt: startedAt,
            endedAt: endedAt,
            customName: customName
        )
        context.insert(session)
        try context.save()
    }

    func testActiveSessionWithCustomNameReturnsTrimmedCustomName() throws {
        try insertSession(startedAt: Date(), customName: "  Morning Run  ")

        let name = try CurrentOutingReader.currentOutingName(context: context)
        XCTAssertEqual(name, "Morning Run")
    }

    func testActiveSessionWithWhitespaceOnlyCustomNameReturnsDateFallback() throws {
        try insertSession(startedAt: Date(timeIntervalSince1970: 1_760_000_000), customName: "   \n\t ")

        let name = try CurrentOutingReader.currentOutingName(context: context)
        XCTAssertFalse(name.isEmpty)
        XCTAssertNotEqual(name, "   \n\t ")
    }

    func testActiveSessionWithNilCustomNameReturnsDateFallback() throws {
        try insertSession(startedAt: Date(timeIntervalSince1970: 1_760_000_000), customName: nil)

        let name = try CurrentOutingReader.currentOutingName(context: context)
        XCTAssertFalse(name.isEmpty)

        // Sanity: the fallback is a formatted date of startedAt, not an arbitrary string.
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        XCTAssertEqual(name, formatter.string(from: Date(timeIntervalSince1970: 1_760_000_000)))
    }

    func testEndedSessionsOnlyThrowsNoActiveOuting() throws {
        try insertSession(startedAt: Date().addingTimeInterval(-3_600), endedAt: Date(), customName: "Closed Outing")

        XCTAssertThrowsError(try CurrentOutingReader.currentOutingName(context: context)) { error in
            guard case IsoMeIntentError.noActiveOuting = error else {
                return XCTFail("Expected noActiveOuting, got \(error)")
            }
        }
    }

    func testMixedSessionsPicksTheActiveOne() throws {
        try insertSession(startedAt: Date().addingTimeInterval(-7_200), endedAt: Date().addingTimeInterval(-3_600), customName: "Older Ended Outing")
        try insertSession(startedAt: Date(), customName: "Live Outing")

        let name = try CurrentOutingReader.currentOutingName(context: context)
        XCTAssertEqual(name, "Live Outing")
    }

    func testMultipleActiveSessionsPicksNewest() throws {
        // Defensive: should never happen in practice, but mirrors the fetch's
        // reverse-sort + fetchLimit 1 behavior from RenameCurrentOutingIntent.
        try insertSession(startedAt: Date().addingTimeInterval(-600), customName: "Older Active")
        try insertSession(startedAt: Date().addingTimeInterval(-60), customName: "Newer Active")

        let name = try CurrentOutingReader.currentOutingName(context: context)
        XCTAssertEqual(name, "Newer Active")
    }

    func testEmptyStoreThrowsNoActiveOuting() throws {
        XCTAssertThrowsError(try CurrentOutingReader.currentOutingName(context: context)) { error in
            guard case IsoMeIntentError.noActiveOuting = error else {
                return XCTFail("Expected noActiveOuting, got \(error)")
            }
        }
    }
}
