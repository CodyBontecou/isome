import XCTest
import Foundation

/// Register ONLY in the future isolated UI target, never in IsoMeTests.
@MainActor
final class PhotoMapIntegrationUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "tech.isolated.synthetic.IsoMePhotoMapHost")
    private enum Failure: Error { case missingNativeElement, missingReceipt, unmetCondition }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws { app.terminate() }

    func testCombinedPreferenceReopenPreservesMembershipAndLegacyChoice() throws {
        try launch(["--fixture-legacy-pins"])
        let initial = try receipt()
        XCTAssertEqual(number(initial, "cachedCount"), 3)
        XCTAssertEqual(number(initial, "places"), 2)
        XCTAssertFalse(flag(initial, "images"))
        try layer("Photo dots")
        let dotted = try receipt()
        XCTAssertTrue(flag(dotted, "dots"))
        XCTAssertFalse(flag(dotted, "images"))
        XCTAssertEqual(number(dotted, "places"), 2)
        app.terminate()
        try launch([], reset: false)
        let reopened = try receipt()
        XCTAssertTrue(flag(reopened, "dots"))
        XCTAssertFalse(flag(reopened, "images"))
        XCTAssertEqual(number(reopened, "cachedCount"), 3)
        XCTAssertEqual(number(reopened, "places"), 2)
        XCTAssertEqual(reopened["membershipDigest"] as? String, initial["membershipDigest"] as? String)
        try layer("Photo dots")
        XCTAssertFalse(flag(try receipt(), "images")) // Legacy pin choice was not overwritten.
        XCTAssertTrue(requests(try receipt()).isEmpty)
        try layer("Photo images")
        try awaitCondition { !(try self.requests(self.receipt())).isEmpty }
    }

    func testCombinedDotButtonsRouteSingletonPlaceAndAreaWithoutMarkerRequests() throws {
        try launch(["--fixture-dots"])
        XCTAssertTrue(requests(try receipt()).isEmpty)
        try tap(photoButtons.firstMatch)
        try require(app.buttons["Close photo"])
        try tap(app.buttons["Close photo"])
        try tap(app.buttons["2 photos taken here"])
        try require(app.navigationBars["Photos Here"])
        try tap(app.buttons["Done"])
        try launch(["--fixture-dots", "--fixture-dense"])
        XCTAssertTrue(requests(try receipt()).isEmpty)
        let area = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "photos in this area")).firstMatch
        try tap(area)
        try require(app.navigationBars["Photos in This Area"])
        try tap(app.buttons["Done"])
        XCTAssertTrue(requests(try receipt()).isEmpty) // Read receipt only after returning to Root.
    }

    func testCombinedBrowseAllReachesOverflowPlaceAnd501PhotoBoundedPages() throws {
        try launch(["--fixture-dots", "--fixture-dense"])
        XCTAssertEqual(number(try receipt(), "places"), 503)
        try tap(app.buttons["Browse 503 photo places"])
        try require(app.navigationBars["All Photo Places"])
        var seen = Set<String>()
        for page in 1...9 {
            try scrollDirectoryToTop()
            try scanDirectoryPage(page: page, into: &seen)
            try require(app.staticTexts["\(page) of 9"])
            if page < 9 { try tap(app.buttons["Next page"]) }
        }
        XCTAssertEqual(seen.count, 503, "Every actual directory row, not just page arithmetic, must be observed")
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        // Locate the complete 501-photo place by actual directory paging/row activation.
        for _ in 0..<8 { try tap(app.buttons["Previous page"]) }
        try findDirectoryPlace(app.buttons["501 photos taken here"])
        try tap(app.buttons["501 photos taken here"])
        try require(app.navigationBars["Photos Here"])
        for page in 1...9 {
            try scrollTo(app.buttons["Next page"])
            try require(app.staticTexts["\(page) of 9"])
            if page < 9 { try tap(app.buttons["Next page"]) }
        }
        XCTAssertFalse(app.buttons["Next page"].isEnabled)
        let lastPagePhotos = photoButtons.allElementsBoundByIndex
        XCTAssertGreaterThan(lastPagePhotos.count, 0)
        XCTAssertLessThanOrEqual(lastPagePhotos.count, 21, "Lazy native AX hydration must remain bounded")
        guard let last = lastPagePhotos.last else { throw Failure.missingNativeElement }
        try tap(last)
        try require(app.buttons["Close photo"])
        try require(app.staticTexts["501 of 501"])
        // Production arrows stay enabled and wrap; exercise the actual native behavior.
        try tap(app.buttons["Next photo"])
        try require(app.staticTexts["1 of 501"])
        try tap(app.buttons["Previous photo"])
        try require(app.staticTexts["501 of 501"])
        try tap(app.buttons["Previous photo"])
        try require(app.staticTexts["500 of 501"])
        try tap(app.buttons["Next photo"])
        try require(app.staticTexts["501 of 501"])
        try tap(app.buttons["Close photo"])
        try tap(app.buttons["Done"])
        try tap(app.buttons["Done"])
        XCTAssertTrue(requests(try receipt()).contains("fixture-photo-0500"))
    }

    func testCombinedRootAndNestedSelectionInvalidatesOnRangeAccessAndSameCountReplacement() throws {
        // Full direct-root and nested matrix. Input is armed before native presentation.
        for nested in [false, true] {
            for change in ["range", "limited", "replacement"] {
                try launch(nested ? ["--fixture-dots", "--fixture-dense"] : ["--fixture-dots"])
                let before = try receipt() // Never query a hidden Root receipt under a modal.
                let event = change == "range" ? "range change" : change == "limited" ? "limited access" : "replacement"
                try input("Arm \(event) on background")
                if nested {
                    try tap(app.buttons["Browse 503 photo places"])
                    try require(app.navigationBars["All Photo Places"])
                    let place = app.buttons["501 photos taken here"]
                    try findDirectoryPlace(place)
                    try tap(place)
                    try require(app.navigationBars["Photos Here"])
                    try tap(photoButtons.firstMatch)
                } else {
                    try tap(photoButtons.firstMatch)
                }
                try require(app.buttons["Close photo"])
                XCUIDevice.shared.press(.home)
                XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
                app.activate()
                try awaitCondition { self.number(try self.receipt(), "appliedInputCount") == 1 }
                let after = try receipt()
                XCTAssertEqual(after["instanceID"] as? String, before["instanceID"] as? String,
                               "A relaunched fixture must not masquerade as selection invalidation")
                for key in ["singletonPresented", "clusterPresented", "directoryPresented", "placePresented", "browserPresented"] {
                    XCTAssertFalse(flag(after, key), key)
                }
                XCTAssertFalse(app.buttons["Close photo"].exists)
                XCTAssertFalse(app.navigationBars["Photos Here"].exists)
                XCTAssertFalse(app.navigationBars["All Photo Places"].exists)
                if change == "replacement" {
                    XCTAssertEqual(number(after, "cachedCount"), number(before, "cachedCount"))
                    XCTAssertEqual(number(after, "places"), number(before, "places"))
                    XCTAssertGreaterThan(number(after, "revision"), number(before, "revision"))
                    XCTAssertNotEqual(after["membershipDigest"] as? String, before["membershipDigest"] as? String)
                }
            }
        }
    }

    func testCombinedLimitedPHChangePreservesCachedMetadataInEveryMarkerMode() throws {
        for mode in ["images", "pins", "dots"] {
            try launch(mode == "pins" ? ["--fixture-legacy-pins"] : mode == "dots" ? ["--fixture-dots"] : [])
            if mode == "images" { try awaitCondition { !(try self.requests(self.receipt())).isEmpty } }
            let before = try receipt()
            try input("Limit same IDs")
            try awaitCondition { (try self.receipt())["access"] as? String == "limited" }
            let after = try receipt()
            XCTAssertEqual(after["cachedDigest"] as? String, before["cachedDigest"] as? String)
            XCTAssertEqual(number(after, "cachedCount"), 3)
            XCTAssertEqual(number(after, "accessibleCount"), 3)
            XCTAssertEqual(number(after, "places"), 2)
            XCTAssertEqual(number(after, "metadataReads"), number(before, "metadataReads"),
                           "Synthetic PHChange with automatic sync off must not fetch/delete cached metadata")
            XCTAssertTrue(app.buttons["Browse 2 photo places"].isHittable)
            try input("Limit last 21 IDs") // Separate dense fixture checks a real inaccessible subset below.
        }
        try launch(["--fixture-dots", "--fixture-dense"])
        let before = try receipt()
        try input("Limit last 21 IDs")
        try awaitCondition { self.number(try self.receipt(), "accessibleCount") == 21 }
        XCTAssertEqual(number(try receipt(), "cachedCount"), 1_003)
        XCTAssertEqual(try receipt()["cachedDigest"] as? String, before["cachedDigest"] as? String)
        XCTAssertTrue(app.buttons["Browse 21 photo places"].isHittable)
    }

    private var photoButtons: XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Photo taken at"))
    }
    private var scrollSurface: XCUIElement {
        app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.scrollViews.firstMatch
    }
    private func launch(_ arguments: [String], reset: Bool = true) throws {
        app.terminate()
        app.launchArguments = ["--demo-open-map-filters", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            + (reset ? ["--fixture-reset-preferences"] : []) + arguments
        app.launch()
        try require(app.staticTexts["photo.fixture.receipt"])
        XCTAssertFalse(app.staticTexts["photo.fixture.failed"].exists)
        XCTAssertFalse(flag(try receipt(), "failed"))
        try awaitCondition { self.number(try self.receipt(), "metadataReads") > 0 }
    }
    private func receipt() throws -> [String: Any] {
        let element = app.staticTexts["photo.fixture.receipt"]
        guard element.exists, let data = element.label.data(using: .utf8), data.count <= 24 * 1_024,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["failed"] as? Bool == false,
              let membership = object["membershipDigest"] as? String, membership.count == 64,
              let cached = object["cachedDigest"] as? String, cached.count == 64,
              let instance = object["instanceID"] as? String, UUID(uuidString: instance) != nil
        else { throw Failure.missingReceipt }
        return object
    }
    private func number(_ receipt: [String: Any], _ key: String) -> Int {
        guard let value = receipt[key] as? NSNumber else { XCTFail("Missing number: \(key)"); return -1 }
        return value.intValue
    }
    private func flag(_ receipt: [String: Any], _ key: String) -> Bool {
        guard let value = receipt[key] as? Bool else { XCTFail("Missing Boolean: \(key)"); return false }
        return value
    }
    private func requests(_ receipt: [String: Any]) -> [String] {
        guard let values = receipt["requestedIDs"] as? [String] else { XCTFail("Missing request inventory"); return [] }
        return values
    }
    private func require(_ element: XCUIElement) throws {
        guard element.waitForExistence(timeout: 5) else {
            XCTFail("Missing native element: \(element)")
            throw Failure.missingNativeElement
        }
    }
    private func tap(_ element: XCUIElement) throws {
        try require(element)
        if !element.isHittable { try scrollTo(element) }
        guard element.isEnabled && element.isHittable else { throw Failure.missingNativeElement }
        element.tap()
    }
    private func scrollTo(_ element: XCUIElement) throws {
        for _ in 0..<40 {
            if element.exists && element.isHittable { return }
            dragDirectoryForward()
        }
        throw Failure.missingNativeElement
    }
    private func layer(_ label: String) throws {
        let button = app.buttons[label]
        for _ in 0..<8 {
            if button.exists && button.isHittable { try tap(button); return }
            app.scrollViews.firstMatch.swipeLeft()
        }
        throw Failure.missingNativeElement
    }
    private func input(_ label: String) throws {
        try tap(app.buttons["photo.fixture.inputs"])
        try tap(app.buttons[label])
    }
    private func awaitCondition(_ body: @escaping () throws -> Bool) throws {
        let predicate = NSPredicate { _, _ in (try? body()) == true }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5)
        guard result == .completed else { throw Failure.unmetCondition }
    }
    private func scrollDirectoryToTop() throws {
        let introduction = app.staticTexts["Every place is listed here, even outside the visible map. Area annotations group places for rendering; they do not represent one shared location."]
        for _ in 0..<40 {
            if introduction.exists && introduction.isHittable { return }
            scrollSurface.swipeDown()
        }
        throw Failure.missingNativeElement
    }
    private func dragDirectoryForward() {
        // Overlap real viewport observations rather than flinging over unobserved rows.
        let surface = scrollSurface
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    }
    private func scanDirectoryPage(page: Int, into seen: inout Set<String>) throws {
        let rows = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+ photos taken here"))
        let indicator = app.staticTexts["\(page) of 9"]
        for _ in 0..<40 {
            for row in rows.allElementsBoundByIndex where row.isHittable {
                guard let value = row.value as? String, !value.isEmpty else { throw Failure.missingNativeElement }
                seen.insert(value)
            }
            if indicator.exists && indicator.isHittable { return }
            dragDirectoryForward()
        }
        throw Failure.missingNativeElement
    }
    private func findDirectoryPlace(_ place: XCUIElement) throws {
        for page in 1...9 {
            try scrollDirectoryToTop()
            for _ in 0..<40 {
                if place.exists && place.isHittable { return }
                let indicator = app.staticTexts["\(page) of 9"]
                if indicator.exists && indicator.isHittable { break }
                dragDirectoryForward()
            }
            guard app.buttons["Next page"].isEnabled else { break }
            try tap(app.buttons["Next page"])
        }
        throw Failure.missingNativeElement
    }
}
