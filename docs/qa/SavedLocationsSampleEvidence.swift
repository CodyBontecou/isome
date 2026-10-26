
// Append only to the existing SavedPlaceManagementTests.swift in the isolated
// 1.7.16 release-source copy. Uses its in-memory makeEnvironment helper.
extension SavedPlaceManagementTests {
    func testSEOSavedLocationsCSV() throws {
        let csv = """
name,latitude,longitude,address,radius_meters
Synthetic stop A,1,2,"Invented example, not a real location",500
Synthetic stop B,1.01,2.01,,
""" + "\n"
        let preview = try SavedPlaceImportService.parse(data: Data(csv.utf8))
        XCTAssertTrue(preview.invalidRows.isEmpty)
        XCTAssertEqual(preview.places.map(\.name), ["Synthetic stop A", "Synthetic stop B"])
        XCTAssertEqual(preview.places.map(\.radiusMeters), [500, 150])
        let (container, viewModel) = try makeEnvironment()
        let historical = Visit(latitude: 1, longitude: 2,
                               arrivedAt: Date(timeIntervalSince1970: 946728000),
                               departedAt: Date(timeIntervalSince1970: 946728900),
                               locationName: "Unchanged historical visit")
        container.mainContext.insert(historical)
        try container.mainContext.save()
        let first = try viewModel.importSavedPlaces(preview.places, duplicates: .keepExisting)
        XCTAssertEqual(first.added, 2)
        XCTAssertEqual(first.updated, 0)
        XCTAssertEqual(first.skipped, 0)
        let stored = try persistedPlaces(in: container).sorted { $0.name < $1.name }
        XCTAssertEqual(stored.count, 2)
        XCTAssertEqual(stored.map(\.latitude), [1, 1.01])
        XCTAssertEqual(stored.map(\.longitude), [2, 2.01])
        XCTAssertEqual(stored.map(\.radiusMeters), [500, 150])
        XCTAssertEqual(stored.first?.address, "Invented example, not a real location")
        let fresh = try SavedPlaceImportService.parse(data: Data(csv.utf8))
        let repeated = try viewModel.importSavedPlaces(fresh.places, duplicates: .keepExisting)
        XCTAssertEqual(repeated.added, 0)
        XCTAssertEqual(repeated.skipped, 2)
        let updated = try viewModel.importSavedPlaces(fresh.places, duplicates: .updateExisting)
        XCTAssertEqual(updated.added, 0)
        XCTAssertEqual(updated.updated, 2)
        XCTAssertEqual(try persistedPlaces(in: container).count, 2)
        XCTAssertEqual(historical.locationName, "Unchanged historical visit")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Visit>()), 1)
    }
}
