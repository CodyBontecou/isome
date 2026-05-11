import SwiftUI
import UIKit
import XCTest
@testable import IsoMe

@MainActor
final class MapSmokeTests: XCTestCase {

    private let fixtureTimestamp = Date(timeIntervalSince1970: 1_777_777_777)

    func testTimestampCalloutSmokeRendersWithFixedFixture() {
        let controller = host(MapMarkerTimestampCallout(timestamp: fixtureTimestamp))

        XCTAssertFalse(MapAccessibility.timestampValue(fixtureTimestamp).isEmpty)
        XCTAssertGreaterThan(controller.view.intrinsicContentSize.width, 0)
        XCTAssertGreaterThan(controller.view.intrinsicContentSize.height, 0)
    }

    func testPathTimestampMarkersHaveAccessibleCalloutContracts() {
        XCTAssertEqual(MapAccessibility.pathStartLabel, "Path start")
        XCTAssertEqual(MapAccessibility.pathEndLabel, "Path end")
        XCTAssertEqual(MapAccessibility.pathTimestampHint, "Double tap to show or hide the timestamp callout.")
        XCTAssertEqual(
            MapAccessibility.timestampValue(fixtureTimestamp),
            fixtureTimestamp.formatted(date: .abbreviated, time: .shortened)
        )
    }

    func testVisitMarkerHasAccessibleNameValueAndHint() {
        let visit = Visit(
            latitude: 37.7749,
            longitude: -122.4194,
            arrivedAt: fixtureTimestamp,
            departedAt: fixtureTimestamp.addingTimeInterval(3_600),
            locationName: "Ferry Building"
        )

        _ = host(VisitMarker(visit: visit, isSelected: false))

        XCTAssertEqual(MapAccessibility.visitMarkerLabel(for: visit), "Visit at Ferry Building")
        XCTAssertEqual(MapAccessibility.visitMarkerValue(for: visit), visit.formattedTimeRange)
        XCTAssertEqual(MapAccessibility.visitMarkerHint, "Double tap to open visit details.")
    }

    func testIconOnlyMapControlsHaveAccessibleLabelsValuesAndHints() {
        for layer in MapLayerKind.allCases {
            XCTAssertEqual(MapAccessibility.layerToggleLabel(for: layer), layer.accessibilityName)
            XCTAssertEqual(MapAccessibility.layerToggleValue(isOn: true), "Shown")
            XCTAssertEqual(MapAccessibility.layerToggleValue(isOn: false), "Hidden")
            XCTAssertTrue(MapAccessibility.layerToggleHint(for: layer, isOn: true).contains("Hides"))
            XCTAssertTrue(MapAccessibility.layerToggleHint(for: layer, isOn: false).contains("Shows"))
        }

        XCTAssertEqual(MapAccessibility.filterToggleLabel(isOpen: false), "Show map controls")
        XCTAssertEqual(MapAccessibility.filterToggleLabel(isOpen: true), "Hide map controls")
        XCTAssertEqual(MapAccessibility.trackingPrimaryLabel(isTracking: false), "Start tracking")
        XCTAssertEqual(MapAccessibility.trackingPrimaryLabel(isTracking: true), "Stop tracking")
        XCTAssertEqual(MapAccessibility.fitMenuLabel, "Fit map")
    }

    func testQuickFilterBarSmokeRendersFixtureControls() {
        let controller = host(QuickFilterBarSmokeFixture())

        XCTAssertGreaterThan(controller.view.intrinsicContentSize.width, 0)
        XCTAssertGreaterThan(controller.view.intrinsicContentSize.height, 0)
    }

    private func host<Content: View>(_ view: Content) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 220)
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
            hasSessionPoints: true,
            onSelectPreset: { _ in },
            onSelectCustom: {},
            onFitContent: {},
            onFitSession: {}
        )
        .frame(width: 390)
    }
}
