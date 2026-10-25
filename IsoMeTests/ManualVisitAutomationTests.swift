import Testing
import SwiftData
import CoreLocation
@testable import IsoMe

@Suite @MainActor
struct ManualVisitAutomationTests {
    private func container() throws -> ModelContainer {
        let schema = Schema([Visit.self, LocationPoint.self, RecordingSession.self, PhotoMoment.self, SavedPlace.self, CountryStay.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
    private let arrival = Date(timeIntervalSince1970: 1_700_000_000)
    private func noLocation() async throws -> CLLocationCoordinate2D {
        Issue.record("Explicit destinations must not request GPS")
        throw ManualVisitIntentError.locationUnavailable
    }

    @Test func savedPlaceCheckInAndCheckoutPersistMetadata() async throws {
        let db = try container()
        // Use a fresh context on the same container to verify actual persistence.
        let writer = ModelContext(db)
        let place = SavedPlace(name: "Library", latitude: 18, longitude: -67, address: "Main Street")
        writer.insert(place); try writer.save()
        let visit = try await ManualVisitAutomation.checkIn(context: writer, name: nil, savedPlaceID: place.id,
            latitude: nil, longitude: nil, at: arrival, currentLocation: noLocation)
        #expect(visit.source == .manual)
        #expect(visit.confirmationStatus == .confirmed)
        #expect(visit.placeSource == .userEntered)
        #expect(visit.address == "Main Street")
        let confirmedAt = visit.confirmedAt
        _ = try ManualVisitAutomation.checkOut(context: writer, visitID: visit.id, at: arrival.addingTimeInterval(60))
        let reader = ModelContext(db)
        let stored = try #require(reader.fetch(FetchDescriptor<Visit>()).first)
        #expect(stored.departedAt == arrival.addingTimeInterval(60))
        #expect(stored.confirmedAt == confirmedAt)
        #expect(stored.source == .manual)
        #expect(stored.originalLatitude == nil)
        #expect(throws: ManualVisitIntentError.self) {
            try ManualVisitAutomation.checkOut(context: writer, visitID: visit.id)
        }
    }

    @Test func coordinatesSkipLocationAndOverlapNeedsExplicitOverride() async throws {
        let db = try container()
        let writer = ModelContext(db)
        let first = try await ManualVisitAutomation.checkIn(context: writer, name: "Cafe", savedPlaceID: nil,
            latitude: 18, longitude: -67, at: arrival, currentLocation: noLocation)
        do {
            _ = try await ManualVisitAutomation.checkIn(context: writer, name: "Office", savedPlaceID: nil,
                latitude: 18, longitude: -67, at: arrival.addingTimeInterval(1), currentLocation: noLocation)
            Issue.record("Overlap saved without explicit override")
        } catch VisitMutationError.overlap { }
        #expect(try writer.fetchCount(FetchDescriptor<Visit>()) == 1)
        let second = try await ManualVisitAutomation.checkIn(context: writer, name: "Office", savedPlaceID: nil,
            latitude: 18, longitude: -67, at: arrival.addingTimeInterval(1), allowOverlap: true, currentLocation: noLocation)
        #expect(throws: ManualVisitIntentError.self) { try ManualVisitAutomation.checkOut(context: writer, visitID: nil) }
        _ = try ManualVisitAutomation.checkOut(context: writer, visitID: first.id, at: arrival.addingTimeInterval(60))
        #expect(second.departedAt == nil)
    }

    @Test func missingLocationPermissionDoesNotCreateVisit() async throws {
        let db = try container(), context = ModelContext(db)
        do {
            _ = try await ManualVisitAutomation.checkIn(context: context, name: "Here", savedPlaceID: nil,
                latitude: nil, longitude: nil, at: arrival, currentLocation: { throw IsoMeIntentError.noLocationPermission })
            Issue.record("Missing permission unexpectedly succeeded")
        } catch IsoMeIntentError.noLocationPermission { }
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 0)
    }

    @Test func currentLocationIsOnlyRequestedWhenNeeded() async throws {
        let db = try container(), context = ModelContext(db)
        var requests = 0
        let visit = try await ManualVisitAutomation.checkIn(context: context, name: "Here", savedPlaceID: nil,
            latitude: nil, longitude: nil, at: arrival, currentLocation: {
                requests += 1
                return CLLocationCoordinate2D(latitude: 18, longitude: -67)
            })
        #expect(requests == 1)
        #expect(visit.latitude == 18)
    }

    @Test func invalidCoordinatesTimesAndMissingPlacesNeverSave() async throws {
        let db = try container(), context = ModelContext(db)
        for (lat, lon) in [(Double.nan, -67.0), (91, -67), (18, 181)] {
            do {
                _ = try await ManualVisitAutomation.checkIn(context: context, name: "Bad", savedPlaceID: nil,
                    latitude: lat, longitude: lon, at: arrival, currentLocation: noLocation)
                Issue.record("Invalid coordinate saved")
            } catch VisitMutationError.invalidInput { }
        }
        do {
            _ = try await ManualVisitAutomation.checkIn(context: context, name: nil, savedPlaceID: UUID(),
                latitude: nil, longitude: nil, at: arrival, currentLocation: noLocation)
            Issue.record("Missing saved place succeeded")
        } catch ManualVisitIntentError.missingPlace { }
        do {
            _ = try await ManualVisitAutomation.checkIn(context: context, name: "Future", savedPlaceID: nil,
                latitude: 18, longitude: -67, at: Date().addingTimeInterval(3600), currentLocation: noLocation)
            Issue.record("Future check-in succeeded")
        } catch ManualVisitIntentError.invalidArrival { }
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 0)
        #expect(throws: ManualVisitIntentError.self) { try ManualVisitAutomation.checkOut(context: context, visitID: nil) }
    }

    @Test func checkoutRejectsAutomaticImportedAndInvalidTimes() throws {
        let db = try container(), context = ModelContext(db)
        for source in [VisitSource.automatic, .imported, .manual] {
            let visit = Visit(latitude: 18, longitude: -67, arrivedAt: arrival, source: source)
            context.insert(visit); try context.save()
            let time = source == .manual ? arrival.addingTimeInterval(-1) : Date()
            #expect(throws: ManualVisitIntentError.self) { try ManualVisitAutomation.checkOut(context: context, visitID: visit.id, at: time) }
            #expect(visit.departedAt == nil)
        }
    }

    @Test func actualIntentPerformUsesSharedStore() async throws {
        let db = try container(), context = ModelContext(db)
        ManualVisitAutomation.foregroundContext = context
        defer { ManualVisitAutomation.foregroundContext = nil }
        var checkIn = CheckInIntent()
        checkIn.name = "Intent Cafe"
        checkIn.latitude = 18
        checkIn.longitude = -67
        checkIn.arrivedAt = arrival
        _ = try await checkIn.perform()
        let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)
        var checkOut = CheckOutIntent()
        checkOut.visit = VisitEntity(visit: visit)
        checkOut.departedAt = arrival.addingTimeInterval(60)
        _ = try await checkOut.perform()
        #expect(visit.departedAt == arrival.addingTimeInterval(60))
        #expect(try ModelContext(db).fetch(FetchDescriptor<Visit>()).first?.departedAt != nil)
    }

    @Test func correctionMetadataSurvivesCheckout() throws {
        let db = try container(), context = ModelContext(db)
        let visit = Visit(latitude: 18, longitude: -67, arrivedAt: arrival, source: .manual,
            confirmationStatus: .corrected, confirmedAt: arrival, placeSource: .appleMaps)
        visit.originalLatitude = 19; visit.originalLongitude = -66; visit.originalLocationName = "Original"
        context.insert(visit); try context.save()
        _ = try ManualVisitAutomation.checkOut(context: context, visitID: visit.id)
        #expect(visit.confirmationStatus == .corrected)
        #expect(visit.originalLatitude == 19)
        #expect(visit.originalLocationName == "Original")
        #expect(visit.placeSource == .appleMaps)
    }

    @Test(arguments: [
        "isome://check-in?latitude=91&longitude=0", "isome://check-in?latitude=18",
        "isome://check-in?latitude=nan&longitude=0", "isome://check-in?name=",
        "isome://check-in?name=A&name=B", "isome://check-in?allowOverlap=true",
        "isome://check-in?arrival=garbage", "isome://log-visit?arrival=2020-01-01T00:00:00Z",
        "isome://log-visit?arrival=2020-01-02T00:00:00Z&departure=2020-01-01T00:00:00Z",
        "isome://user@check-in", "isome://visit/not-a-uuid", "https://check-in",
        "isome://check-in/extra", "isome://check-in#fragment"
    ])
    func rejectsMalformedLinks(_ raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(throws: ManualVisitRoute.RouteError.self) { try ManualVisitRoute.parse(url) }
    }

    @Test func validLinksProduceDraftsAndDetailsOnly() throws {
        let id = UUID()
        #expect(try ManualVisitRoute.parse(#require(URL(string: "isome://visit/\(id)"))) == .visit(id))
        #expect(try ManualVisitRoute.parse(#require(URL(string: "isome://check-in?name=Coffee%20Shop&latitude=18&longitude=-67"))) == .checkIn(name: "Coffee Shop", latitude: 18, longitude: -67, arrival: nil))
        #expect(try ManualVisitRoute.parse(#require(URL(string: "isome://log-visit"))) == .pastVisit(name: nil, latitude: nil, longitude: nil, arrival: nil, departure: nil))
    }
}
