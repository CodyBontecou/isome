// Run as an extension of the existing ExportRoundTripTests in an isolated
// simulator rebuild of release source 6ae78e6. This is documentation QA only.
// The XCTest target supplies XCTest and @testable import IsoMe.
extension ExportRoundTripTests {
    @MainActor
    func testSEOObsidianMarkdownArtifact() throws {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        defer { NSTimeZone.default = previousTimeZone }

        let firstArrival = Date(timeIntervalSince1970: 946727100)
        let secondArrival = Date(timeIntervalSince1970: 946728120)
        let visits = [
            Visit(latitude: 0, longitude: 0, arrivedAt: firstArrival,
                  departedAt: firstArrival.addingTimeInterval(900),
                  locationName: "Synthetic stop A",
                  notes: "Invented documentation example; not a real visit.",
                  source: .imported),
            Visit(latitude: 0.0002, longitude: 0.0001, arrivedAt: secondArrival,
                  departedAt: secondArrival.addingTimeInterval(900),
                  locationName: "Synthetic stop B",
                  notes: "Invented documentation example; not a real visit.",
                  source: .imported)
        ]
        var options = ExportOptions()
        options.dataKind = .visits
        options.format = .markdown
        options.datePreset = .allTime
        options.includeVisitAddress = false
        let rendered = try ExportService.render(
            visits: visits, points: [], options: options,
            filenamePattern: "synthetic-obsidian-export.md"
        )
        XCTAssertEqual(rendered.fileName, "synthetic-obsidian-export.md")
        let parsed = try ImportService.importFile(data: rendered.data, format: .markdown)
        XCTAssertEqual(parsed.visits.count, 2)
        XCTAssertTrue(parsed.points.isEmpty)
        XCTAssertEqual(parsed.visits.map(\.locationName), ["Synthetic stop A", "Synthetic stop B"])
        XCTAssertEqual(parsed.visits.map(\.arrivedAt), [firstArrival, secondArrival])
        XCTAssertEqual(parsed.visits.last?.latitude, 0.0002)
        XCTAssertEqual(parsed.visits.last?.longitude, 0.0001)
        print("SEO_OBSIDIAN_EXPORT_BEGIN" + rendered.data.base64EncodedString() + "SEO_OBSIDIAN_EXPORT_END")
    }
}
