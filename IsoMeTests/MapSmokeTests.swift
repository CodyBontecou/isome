import SwiftUI
import UIKit
import XCTest
@testable import IsoMe

@MainActor
final class MapSmokeTests: XCTestCase {

    private let fixtureTimestamp = Date(timeIntervalSince1970: 1_777_777_777)

    func testPathTimestampMarkersSmokeRenderWithFixedFixture() {
        let formattedTimestamp = fixtureTimestamp.formatted(date: .abbreviated, time: .shortened)

        XCTAssertFalse(formattedTimestamp.isEmpty)
        assertSmokeRenders(PathStartMarker(timestamp: fixtureTimestamp), named: "Path start marker")
        assertSmokeRenders(PathEndMarker(timestamp: fixtureTimestamp), named: "Path end marker")
    }

    func testVisitMarkerUsesVisitAccessibilityContract() {
        let visit = Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: fixtureTimestamp,
            departedAt: fixtureTimestamp.addingTimeInterval(3_600),
            locationName: "Ferry Building",
            address: "1 Ferry Building, San Francisco, CA"
        )

        assertSmokeRenders(VisitMarker(visit: visit, isSelected: false), named: "Visit marker")

        XCTAssertEqual(visit.accessibilityLabel, "Visit at Ferry Building")
        XCTAssertTrue(visit.accessibilityValue.contains(visit.formattedTimeRange))
        XCTAssertTrue(visit.accessibilityValue.contains(visit.formattedDuration))
        XCTAssertTrue(visit.accessibilityValue.contains("1 Ferry Building, San Francisco, CA"))
        XCTAssertTrue(visit.accessibilityValue.contains("Latitude 37.7749, longitude -122.4194"))
        XCTAssertEqual(visit.accessibilityHint, "Opens visit details.")
    }

    func testCurrentVisitMarkerUsesCurrentVisitAccessibilityContract() {
        let visit = Visit(
            latitude: 37.7849,
            longitude: -122.4094,
            arrivedAt: fixtureTimestamp,
            locationName: "Market Street"
        )

        assertSmokeRenders(VisitMarker(visit: visit, isSelected: true), named: "Selected current visit marker")

        XCTAssertEqual(visit.accessibilityLabel, "Current visit at Market Street")
        XCTAssertTrue(visit.accessibilityValue.contains("Still here"))
        XCTAssertEqual(visit.accessibilityHint, "Opens visit details.")
    }

    func testLocationPointAccessibilityValueSummarizesFixedFixture() {
        let point = LocationPoint(
            latitude: 37.7750,
            longitude: -122.4195,
            timestamp: fixtureTimestamp,
            altitude: 12,
            speed: 1.2,
            horizontalAccuracy: 8,
            isOutlier: true
        )

        XCTAssertEqual(point.accessibilityTimestamp, fixtureTimestamp.formatted(date: .abbreviated, time: .shortened))
        XCTAssertEqual(point.accessibilityCoordinateSummary, "Latitude 37.7750, longitude -122.4195")
        XCTAssertEqual(point.accessibilityAccuracySummary, "Accuracy about 8 meters")
        XCTAssertTrue(point.accessibilityValue.contains(point.accessibilityTimestamp))
        XCTAssertTrue(point.accessibilityValue.contains(point.accessibilityCoordinateSummary))
        XCTAssertTrue(point.accessibilityValue.contains(point.accessibilityAccuracySummary))
        XCTAssertTrue(point.accessibilityValue.contains("Speed 1.2 meters per second"))
        XCTAssertTrue(point.accessibilityValue.contains("Marked as an outlier"))
    }

    func testLocationPointTimestampCalloutSmokeRendersFixedFixture() {
        let point = LocationPoint(
            latitude: 37.7750,
            longitude: -122.4195,
            timestamp: fixtureTimestamp,
            horizontalAccuracy: 8
        )

        assertSmokeRenders(
            LocationPointTimestampCallout(point: point, onDismiss: {}),
            named: "Location point timestamp callout"
        )
        XCTAssertTrue(point.accessibilityValue.contains(fixtureTimestamp.formatted(date: .abbreviated, time: .shortened)))
    }

    func testMapDatePresetAccessibilityLabelsMatchVisiblePresets() {
        XCTAssertEqual(MapDatePreset.today.accessibilityLabel, "Today")
        XCTAssertEqual(MapDatePreset.sevenDays.accessibilityLabel, "Last 7 days")
        XCTAssertEqual(MapDatePreset.thirtyDays.accessibilityLabel, "Last 30 days")
        XCTAssertEqual(MapDatePreset.all.accessibilityLabel, "All time")

        let sevenDayRange = MapDatePreset.sevenDays.range(referenceDate: fixtureTimestamp)
        XCTAssertEqual(sevenDayRange.upperBound, fixtureTimestamp)
        XCTAssertLessThan(sevenDayRange.lowerBound, sevenDayRange.upperBound)
    }

    func testIconOnlyMapControlsSmokeRenderWithCurrentLabels() {
        let layerControls: [(systemImage: String, label: String)] = [
            ("mappin.circle.fill", "Visit markers"),
            ("point.topleft.down.to.point.bottomright.curvepath", "Travel path"),
            ("smallcircle.filled.circle", "Point markers"),
            ("flag.fill", "Start and end markers"),
            ("waveform.path.ecg", "Active session path")
        ]

        XCTAssertEqual(layerControls.map { $0.label }, [
            "Visit markers",
            "Travel path",
            "Point markers",
            "Start and end markers",
            "Active session path"
        ])

        for control in layerControls {
            assertSmokeRenders(
                LayerToggleButton(
                    systemImage: control.systemImage,
                    label: control.label,
                    isOn: .constant(true)
                ),
                named: control.label
            )
        }

        assertSmokeRenders(FilterBarToggle(isOpen: false, action: {}), named: "Closed filter toggle")
        assertSmokeRenders(FilterBarToggle(isOpen: true, action: {}), named: "Open filter toggle")
        assertSmokeRenders(FitMenuButton(onFitContent: {}, onFitSession: {}), named: "Fit menu")
    }

    func testQuickFilterBarSmokeRendersFixtureControls() {
        assertSmokeRenders(QuickFilterBarSmokeFixture(), named: "Quick filter bar")
    }

    private func assertSmokeRenders<Content: View>(
        _ view: Content,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let controller = host(view)
        let fittingSize = controller.sizeThatFits(in: CGSize(width: 390, height: 220))

        XCTAssertGreaterThan(fittingSize.width, 0, "\(name) should have a positive fitting width", file: file, line: line)
        XCTAssertGreaterThan(fittingSize.height, 0, "\(name) should have a positive fitting height", file: file, line: line)
    }

    private func host<Content: View>(_ view: Content) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 220)
        controller.view.backgroundColor = .clear
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return controller
    }
}

private struct QuickFilterBarSmokeFixture: View {
    @State private var showTravelPath = true
    @State private var showPointMarkers = true
    @State private var showStartEndMarkers = true
    @State private var showSessionPath = true
    @State private var showVisitMarkers = true

    var body: some View {
        QuickFilterBar(
            activePreset: .today,
            showTravelPath: $showTravelPath,
            showPointMarkers: $showPointMarkers,
            showStartEndMarkers: $showStartEndMarkers,
            showSessionPath: $showSessionPath,
            showVisitMarkers: $showVisitMarkers,
            showsVisitLayer: true,
            hasSessionPoints: true,
            onSelectPreset: { _ in },
            onSelectCustom: {},
            onFitContent: {},
            onFitSession: {}
        )
        .frame(width: 390)
    }
}
