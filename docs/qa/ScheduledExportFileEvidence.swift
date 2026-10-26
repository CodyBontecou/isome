// Documentation evidence only; append to the isolated release-source
// IntervalScheduledExportTests.swift. Production code is unchanged.
extension IntervalScheduledExportTests {
    @MainActor
    func testDocumentationAppendBoundaryCSVAndJSONFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let calendar = Calendar.current
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)))
        let ten = start.addingTimeInterval(10 * 3600)
        let eleven = start.addingTimeInterval(11 * 3600)
        let twelve = start.addingTimeInterval(12 * 3600)
        let points = [ten, eleven, twelve].enumerated().map { index, date in
            LocationPoint(latitude: Double(index) * 0.0001, longitude: 0, timestamp: date, horizontalAccuracy: 5)
        }
        for format in [ExportFormat.csv, .json] {
            let first = try documentationWrite(root: root, format: format, mode: .append, now: eleven, cursor: nil, visits: [], points: Array(points.prefix(2)))
            let second = try documentationWrite(root: root, format: format, mode: .append, now: twelve, cursor: eleven, visits: [], points: points)
            XCTAssertEqual(first, second)
            let payload = try ImportService.importFile(data: Data(contentsOf: second), format: format)
            XCTAssertEqual(payload.points.count, format == .csv ? 4 : 3)
            XCTAssertEqual(payload.points.filter { $0.timestamp == eleven }.count, format == .csv ? 2 : 1)
        }
    }

    @MainActor
    func testDocumentationRewriteRefreshesAVisitThatAppendLeavesOpen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let start = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)))
        let ten = start.addingTimeInterval(10 * 3600)
        let eleven = start.addingTimeInterval(11 * 3600)
        let twelve = start.addingTimeInterval(12 * 3600)
        let visit = Visit(latitude: 0, longitude: 0, arrivedAt: ten, locationName: "Synthetic scheduled stop")
        _ = try documentationWrite(root: root, format: .json, mode: .append, now: eleven, cursor: nil, visits: [visit], points: [])
        visit.departedAt = twelve
        let appended = try documentationWrite(root: root, format: .json, mode: .append, now: twelve, cursor: eleven, visits: [visit], points: [])
        let appendResult = try ImportService.importFile(data: Data(contentsOf: appended), format: .json)
        XCTAssertEqual(appendResult.visits.count, 1)
        XCTAssertNil(try XCTUnwrap(appendResult.visits.first).departedAt)
        let rewritten = try documentationWrite(root: root, format: .json, mode: .rewrite, now: twelve, cursor: eleven, visits: [visit], points: [])
        XCTAssertEqual(appended, rewritten)
        let rewriteResult = try ImportService.importFile(data: Data(contentsOf: rewritten), format: .json)
        XCTAssertEqual(try XCTUnwrap(rewriteResult.visits.first).departedAt, twelve)
    }

    @MainActor
    func testDocumentationAfterMidnightDoesNotRepairYesterdayFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let calendar = Calendar.current
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        let early = LocationPoint(latitude: 0, longitude: 0, timestamp: nextDay.addingTimeInterval(-600), horizontalAccuracy: 5)
        let late = LocationPoint(latitude: 0.0001, longitude: 0, timestamp: nextDay.addingTimeInterval(-60), horizontalAccuracy: 5)
        let today = LocationPoint(latitude: 0.0002, longitude: 0, timestamp: nextDay.addingTimeInterval(300), horizontalAccuracy: 5)
        let yesterdayURL = try documentationWrite(root: root, format: .json, mode: .rewrite, now: nextDay.addingTimeInterval(-300), cursor: nil, visits: [], points: [early])
        let yesterdayData = try Data(contentsOf: yesterdayURL)
        let todayURL = try documentationWrite(root: root, format: .json, mode: .rewrite, now: nextDay.addingTimeInterval(600), cursor: nil, visits: [], points: [early, late, today])
        XCTAssertNotEqual(todayURL, yesterdayURL)
        XCTAssertEqual(try Data(contentsOf: yesterdayURL), yesterdayData)
        let todayResult = try ImportService.importFile(data: Data(contentsOf: todayURL), format: .json)
        XCTAssertEqual(todayResult.points.count, 1)
        XCTAssertEqual(todayResult.points.first?.timestamp, today.timestamp)
        let yesterdayResult = try ImportService.importFile(data: yesterdayData, format: .json)
        XCTAssertEqual(yesterdayResult.points.count, 1)
        XCTAssertEqual(yesterdayResult.points.first?.timestamp, early.timestamp)
    }

    @MainActor
    private func documentationWrite(root: URL, format: ExportFormat, mode: ScheduledExportFileMode, now: Date, cursor: Date?, visits: [Visit], points: [LocationPoint]) throws -> URL {
        var options = ExportOptions()
        options.format = format
        options.dataKind = visits.isEmpty ? .points : .visits
        let plan = IsoMeScheduledExportPlan.resolve(baseOptions: options, filenamePattern: "synthetic-{date}", intervalHours: 1, fileMode: mode, appendCursor: cursor, now: now)
        let files = try IsoMeExportKitAdapter.plannedFiles(visits: visits, points: points, options: plan.options, filenamePattern: plan.filenamePattern, aggregateFilenameDate: plan.filenameDate)
        let file = try XCTUnwrap(files.first)
        XCTAssertEqual(files.count, 1)
        let writer = ExportFileWriter(fileSystem: FileManagerExportFileSystem())
        return try writer.write(file, to: ExportDestination(rootURL: root), mode: plan.writeMode, mergeStrategy: plan.mergeStrategy).url
    }
}
