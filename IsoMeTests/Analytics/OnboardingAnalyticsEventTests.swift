//
//  OnboardingAnalyticsEventTests.swift
//  IsoMeTests
//
//  Tests for the privacy-safe onboarding analytics event model.
//

import XCTest
@testable import IsoMe

final class OnboardingAnalyticsEventTests: XCTestCase {

    func testPayloadEncodesOnlyAllowlistedProperties() {
        let event = OnboardingAnalyticsEvent(
            name: .onboardingCompleted,
            properties: OnboardingAnalyticsProperties(
                appVersion: "1.8.2",
                buildNumber: "204",
                platform: .iOS,
                onboardingStep: .ready,
                authorizationStatus: .always,
                authorizationRequestKind: .always,
                trackingIntent: .startImmediately,
                paywallContext: .export,
                productId: .lifetimeUnlock,
                purchaseOutcome: .succeeded,
                errorCategory: .networkUnavailable
            )
        )

        let payload = event.encodedPayload()

        XCTAssertEqual(payload.eventName, "onboarding_completed")
        XCTAssertEqual(
            Set(payload.properties.keys),
            Set(OnboardingAnalyticsPropertyKey.allCases),
            "The encoded model should contain every allowlisted property and no arbitrary keys."
        )
        XCTAssertEqual(payload.properties[.appVersion], .string("1.8.2"))
        XCTAssertEqual(payload.properties[.buildNumber], .string("204"))
        XCTAssertEqual(payload.properties[.platform], .string("ios"))
        XCTAssertEqual(payload.properties[.onboardingStep], .string("ready"))
        XCTAssertEqual(payload.properties[.authorizationStatus], .string("always"))
        XCTAssertEqual(payload.properties[.authorizationRequestKind], .string("always"))
        XCTAssertEqual(payload.properties[.trackingIntent], .string("start_immediately"))
        XCTAssertEqual(payload.properties[.paywallContext], .string("export"))
        XCTAssertEqual(payload.properties[.productId], .string("com.bontecou.isome.lifetime"))
        XCTAssertEqual(payload.properties[.purchaseOutcome], .string("succeeded"))
        XCTAssertEqual(payload.properties[.errorCategory], .string("network_unavailable"))
    }

    func testEventNamesAreCoarseAndOnboardingScoped() {
        let names = Set(OnboardingAnalyticsEventName.allCases.map(\.rawValue))

        XCTAssertTrue(names.contains("onboarding_started"))
        XCTAssertTrue(names.contains("onboarding_step_viewed"))
        XCTAssertTrue(names.contains("onboarding_location_authorization_requested"))
        XCTAssertTrue(names.contains("onboarding_location_authorization_completed"))
        XCTAssertTrue(names.contains("onboarding_tracking_intent_changed"))
        XCTAssertTrue(names.contains("onboarding_completed"))
        XCTAssertTrue(names.contains("onboarding_paywall_shown"))
        XCTAssertTrue(names.contains("onboarding_purchase_started"))
        XCTAssertTrue(names.contains("onboarding_purchase_finished"))
        XCTAssertTrue(names.contains("onboarding_restore_started"))
        XCTAssertTrue(names.contains("onboarding_restore_finished"))

        for name in names {
            XCTAssertTrue(name.hasPrefix("onboarding_"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("latitude"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("longitude"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("address"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("place"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("route"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("path"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("webhook"))
            XCTAssertFalse(name.localizedCaseInsensitiveContains("url"))
        }
    }

    func testDisallowedPropertyKeysAreNotRepresentable() {
        let prohibitedKeys = [
            "latitude",
            "longitude",
            "coordinate",
            "address",
            "placeName",
            "visitName",
            "routePoint",
            "locationTimestamp",
            "rawDate",
            "exportedJSON",
            "filePath",
            "folderName",
            "webhookURL",
            "deviceName",
            "userText"
        ]

        for key in prohibitedKeys {
            XCTAssertNil(
                OnboardingAnalyticsPropertyKey(rawValue: key),
                "\(key) must not be an encodable onboarding analytics property key."
            )
        }
    }

    func testSensitiveStringExamplesAreOmittedAtEncodingBoundary() {
        let sensitiveValues = [
            "/Users/cody/Documents/iso.me",
            "2026-05-14",
            "Home address",
            "37.7749,-122.4194",
            "https://example.com/webhook",
            "Cody's iPhone"
        ]

        for sensitiveValue in sensitiveValues {
            let event = OnboardingAnalyticsEvent(
                name: .onboardingStarted,
                properties: OnboardingAnalyticsProperties(
                    appVersion: sensitiveValue,
                    buildNumber: sensitiveValue
                )
            )

            let payload = event.encodedPayload()

            XCTAssertFalse(
                payload.properties.values.contains(.string(sensitiveValue)),
                "Sensitive value \(sensitiveValue) should be rejected or omitted."
            )
        }
    }

    func testModelSourceDoesNotImportLocationStoreKitOrTransportFrameworks() throws {
        let source = try onboardingAnalyticsEventSource()

        XCTAssertFalse(source.contains("import CoreLocation"))
        XCTAssertFalse(source.contains("import SwiftData"))
        XCTAssertFalse(source.contains("import StoreKit"))
        XCTAssertFalse(source.contains("URLSession"))
        XCTAssertFalse(source.contains("CLLocation"))
        XCTAssertFalse(source.contains("CLVisit"))
        XCTAssertFalse(source.contains("StoreKit.Product"))
        XCTAssertFalse(source.contains("Transaction"))
    }

    private func onboardingAnalyticsEventSource() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        var searchDirectory = testFile.deletingLastPathComponent()

        for _ in 0..<8 {
            let sourceURL = searchDirectory
                .appendingPathComponent("IsoMe")
                .appendingPathComponent("Services")
                .appendingPathComponent("Analytics")
                .appendingPathComponent("OnboardingAnalyticsEvent.swift")

            if FileManager.default.fileExists(atPath: sourceURL.path) {
                return try String(contentsOf: sourceURL, encoding: .utf8)
            }

            searchDirectory.deleteLastPathComponent()
        }

        throw NSError(
            domain: "OnboardingAnalyticsEventTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Could not locate OnboardingAnalyticsEvent.swift from \(#filePath)."]
        )
    }
}
