import XCTest
@testable import IsoMe

final class SavedPlaceImportTests: XCTestCase {
    func testParsesReorderedBOMHeadersAndOptionalValues() throws {
        let preview = try parse("\u{FEFF} LONGITUDE ,name,latitude,radius_meters,address,extra\r\n-9.1393, Home ,38.7223,,  Lisbon  ,ignored\r\n-9.14,Office,38.73,25,,ignored")

        XCTAssertTrue(preview.invalidRows.isEmpty)
        XCTAssertEqual(preview.places.count, 2)
        let home = try XCTUnwrap(preview.places.first)
        XCTAssertEqual(home.name, "Home")
        XCTAssertEqual(home.address, "Lisbon")
        XCTAssertEqual(home.latitude, 38.7223)
        XCTAssertEqual(home.longitude, -9.1393)
        XCTAssertEqual(home.radiusMeters, 150)
        XCTAssertEqual(preview.places[1].radiusMeters, 25)
        XCTAssertNil(preview.places[1].address)
        XCTAssertNotEqual(home.id, preview.places[1].id)
        XCTAssertEqual(preview.rows.map(\.rowNumber), [2, 3])
    }

    func testQuotedCommasEscapedQuotesAndMultilineAddressesPreserveData() throws {
        let preview = try parse("name,latitude,longitude,address\r\n\"Café, \"\"Rue\"\"\",38,-9,\"Floor 1\r\n10 Example Street, Lisbon\"\r\nPark,39,-8,Green\r\n")

        XCTAssertTrue(preview.invalidRows.isEmpty)
        XCTAssertEqual(preview.places.count, 2)
        XCTAssertEqual(preview.places[0].name, "Café, \"Rue\"")
        XCTAssertEqual(preview.places[0].address, "Floor 1\r\n10 Example Street, Lisbon")
        XCTAssertEqual(preview.rows.map(\.rowNumber), [2, 4])
    }

    func testInvalidRowsRemainInPreviewWithoutDiscardingValidNeighbors() throws {
        let preview = try parse("""
        name,latitude,longitude,radius_meters
        Valid,90,-180,10000
        ,38,-9,150
        Bad latitude,91,-9,150
        Bad longitude,38,-181,150
        Short,38,-9
        Long,38,-9,150,unexpected
        Another valid,-90,180,25
        """)

        XCTAssertEqual(preview.rows.count, 7)
        XCTAssertEqual(preview.places.map(\.name), ["Valid", "Another valid"])
        XCTAssertEqual(preview.invalidRows.map(\.rowNumber), [3, 4, 5, 6, 7])
        XCTAssertTrue(preview.invalidRows.allSatisfy { $0.place == nil && !$0.errors.isEmpty })
        XCTAssertTrue(preview.invalidRows[3].errors.contains { $0.contains("Expected 4 columns, found 3") })
        XCTAssertTrue(preview.invalidRows[4].errors.contains { $0.contains("Expected 4 columns, found 5") })
    }

    func testRejectsNonFiniteAndInvalidNumericValues() throws {
        let invalidValues = ["nan", "inf", "-inf", "1e309", "not a number", ""]
        for value in invalidValues {
            for column in ["latitude", "longitude"] {
                let latitude = column == "latitude" ? value : "38"
                let longitude = column == "longitude" ? value : "-9"
                let preview = try parse("name,latitude,longitude\nPlace,\(latitude),\(longitude)")
                XCTAssertTrue(preview.places.isEmpty, "Accepted \(column): \(value)")
                XCTAssertEqual(preview.invalidRows.count, 1)
            }
        }
        for value in ["nan", "inf", "-inf", "1e309", "-1", "0", "24.9", "10000.1", "large"] {
            let preview = try parse("name,latitude,longitude,radius_meters\nPlace,38,-9,\(value)")
            XCTAssertTrue(preview.places.isEmpty, "Accepted radius: \(value)")
            XCTAssertEqual(preview.invalidRows.count, 1)
        }
    }

    func testMalformedQuotedRowsProduceErrorsAndAllowFollowingRows() throws {
        let preview = try parse("name,latitude,longitude\n\"Bad\"suffix,38,-9\nUn\"escaped,38,-9\nGood,38,-9\n\"Unclosed,38,-9")

        XCTAssertEqual(preview.rows.count, 4)
        XCTAssertEqual(preview.places.map(\.name), ["Good"])
        XCTAssertEqual(preview.invalidRows.map(\.rowNumber), [2, 3, 5])
        XCTAssertTrue(preview.invalidRows[0].errors.contains { $0.contains("Unexpected text") })
        XCTAssertTrue(preview.invalidRows[1].errors.contains { $0.contains("Quotation marks must enclose") })
        XCTAssertTrue(preview.invalidRows[2].errors.contains { $0.contains("closing quotation mark") })
    }

    func testMissingDuplicateAndMalformedHeadersThrowFileErrors() {
        for csv in [
            "name,latitude\nPlace,38",
            "name,latitude,longitude,name\nPlace,38,-9,Other",
            "name,latitude,longitude, LATITUDE \nPlace,38,-9,38",
            "name,latitude,longitude,\nPlace,38,-9,",
            "\"name\"junk,latitude,longitude\nPlace,38,-9",
            "\"name,latitude,longitude\nPlace,38,-9",
            "",
            "name,latitude,longitude\n"
        ] {
            XCTAssertThrowsError(try parse(csv)) { error in
                XCTAssertTrue(error is SavedPlaceImportError, "Unexpected error for \(csv)")
            }
        }
    }

    func testBlankLinesAreIgnoredButEmptyNameRecordsAreReported() throws {
        let preview = try parse("name,latitude,longitude\n\n   \nGood,38,-9\n,,\n\nAnother,39,-8\n")

        XCTAssertEqual(preview.rows.map(\.rowNumber), [4, 5, 7])
        XCTAssertEqual(preview.places.map(\.name), ["Good", "Another"])
        XCTAssertEqual(preview.invalidRows.count, 1)
        XCTAssertEqual(preview.invalidRows[0].rowNumber, 5)
    }

    func testDuplicatePlacesRemainAvailableForPreviewClassification() throws {
        let preview = try parse("name,latitude,longitude\nHome,38,-9\nHome,38,-9")

        XCTAssertEqual(preview.places.count, 2)
        XCTAssertEqual(preview.places.map(\.name), ["Home", "Home"])
        XCTAssertNotEqual(preview.places[0].id, preview.places[1].id)
    }

    func testAnEmptyQuotedRecordIsReportedInsteadOfTreatedAsABlankLine() throws {
        let preview = try parse("name,latitude,longitude\n\"\"\nGood,38,-9")

        XCTAssertEqual(preview.rows.count, 2)
        XCTAssertEqual(preview.invalidRows.map(\.rowNumber), [2])
        XCTAssertEqual(preview.places.map(\.name), ["Good"])
    }

    func testInvalidUTF8AndOversizedFilesThrow() {
        XCTAssertThrowsError(try SavedPlaceImportService.parse(data: Data([0xFF, 0xFE])))
        let oversizedData = Data(repeating: 0x61, count: SavedPlaceImportService.maximumFileSize + 1)
        XCTAssertThrowsError(try SavedPlaceImportService.parse(data: oversizedData))
    }

    func testRowLimitCountsRecordsIncludingMultilineFields() {
        let row = "\"Home\nOffice\",38,-9\n"
        let csv = "name,latitude,longitude\n" + String(repeating: row, count: SavedPlaceImportService.maximumRowCount + 1)

        XCTAssertThrowsError(try parse(csv)) { error in
            XCTAssertTrue(error.localizedDescription.contains("10,000"))
        }
    }

    private func parse(_ csv: String) throws -> SavedPlaceImportPreview {
        try SavedPlaceImportService.parse(data: Data(csv.utf8))
    }
}
