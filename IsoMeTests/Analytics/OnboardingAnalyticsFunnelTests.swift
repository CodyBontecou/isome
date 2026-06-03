//
//  OnboardingAnalyticsFunnelTests.swift
//  IsoMeTests
//
//  Regression coverage for privacy-safe onboarding funnel event builders.
//

import XCTest
@testable import IsoMe

final class OnboardingAnalyticsFunnelTests: XCTestCase {

    func testTypedOnboardingStartedBuildsCoarseStepPayload() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.started",
            maxQueueSize: 5,
            isEnabled: true
        )

        client.trackOnboardingStarted(
            step: .welcome,
            authorizationStatus: .notDetermined
        )
        await client.flushAndWait()

        let payloads = await transport.payloadsValue()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.eventName, "onboarding_started")
        XCTAssertEqual(payloads.first?.properties[.onboardingStep], .string("welcome"))
        XCTAssertEqual(payloads.first?.properties[.authorizationStatus], .string("not_determined"))
        XCTAssertNil(payloads.first?.transportProperties["latitude"])
        XCTAssertNil(payloads.first?.transportProperties["longitude"])
        XCTAssertNil(payloads.first?.transportProperties["address"])
    }

    func testTypedStepViewedBuildsPermissionPayloadWithoutRawLocationData() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.step",
            maxQueueSize: 5,
            isEnabled: true
        )

        client.trackOnboardingStepViewed(
            .permissions,
            authorizationStatus: .whenInUse,
            trackingIntent: nil
        )
        await client.flushAndWait()

        let payload = await transport.firstPayload()
        XCTAssertEqual(payload?.eventName, "onboarding_step_viewed")
        XCTAssertEqual(payload?.properties[.platform], .string("ios"))
        XCTAssertEqual(payload?.properties[.onboardingStep], .string("permissions"))
        XCTAssertEqual(payload?.properties[.authorizationStatus], .string("when_in_use"))
        XCTAssertNil(payload?.properties[.trackingIntent])
        XCTAssertNil(payload?.transportProperties["placeName"])
        XCTAssertNil(payload?.transportProperties["routePoint"])
        XCTAssertNil(payload?.transportProperties["locationTimestamp"])
    }

    func testTypedAuthorizationRequestAndCompletionPayloads() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.auth",
            maxQueueSize: 5,
            isEnabled: true
        )

        client.trackLocationAuthorizationRequested(
            requestKind: .always,
            status: .whenInUse
        )
        client.trackLocationAuthorizationCompleted(status: .always)
        await client.flushAndWait()

        let payloads = await transport.payloadsValue()
        XCTAssertEqual(payloads.map(\.eventName), [
            "onboarding_location_authorization_requested",
            "onboarding_location_authorization_completed"
        ])
        XCTAssertEqual(payloads.first?.properties[.authorizationRequestKind], .string("always"))
        XCTAssertEqual(payloads.first?.properties[.authorizationStatus], .string("when_in_use"))
        XCTAssertEqual(payloads.last?.properties[.authorizationStatus], .string("always"))
    }

    func testTypedCompletionIncludesOnlyCoarseTrackingIntent() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.completed",
            maxQueueSize: 5,
            isEnabled: true
        )

        client.trackOnboardingCompleted(
            authorizationStatus: .always,
            trackingIntent: .startImmediately
        )
        await client.flushAndWait()

        let payload = await transport.firstPayload()
        XCTAssertEqual(payload?.eventName, "onboarding_completed")
        XCTAssertEqual(payload?.properties[.onboardingStep], .string("ready"))
        XCTAssertEqual(payload?.properties[.authorizationStatus], .string("always"))
        XCTAssertEqual(payload?.properties[.trackingIntent], .string("start_immediately"))
    }

    func testTypedPaywallAndPurchaseEventsBuildContextPayloads() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.purchase",
            maxQueueSize: 5,
            isEnabled: true
        )

        client.trackPaywallShown(context: .settings)
        client.trackPurchaseStarted(context: .settings)
        client.trackPurchaseFinished(outcome: .succeeded, context: .settings)
        await client.flushAndWait()

        let payloads = await transport.payloadsValue()
        XCTAssertEqual(payloads.map(\.eventName), [
            "onboarding_paywall_shown",
            "onboarding_purchase_started",
            "onboarding_purchase_finished"
        ])
        XCTAssertEqual(payloads[0].properties[.paywallContext], .string("settings"))
        XCTAssertEqual(payloads[1].properties[.productId], .string("com.bontecou.isome.lifetime"))
        XCTAssertEqual(payloads[1].properties[.purchaseOutcome], .string("started"))
        XCTAssertEqual(payloads[2].properties[.purchaseOutcome], .string("succeeded"))
    }
}

private actor RecordingOnboardingAnalyticsTransport: OnboardingAnalyticsTransport {
    private(set) var payloads: [OnboardingAnalyticsPayload] = []

    func send(_ payload: OnboardingAnalyticsPayload) async throws {
        payloads.append(payload)
    }

    func payloadsValue() -> [OnboardingAnalyticsPayload] {
        payloads
    }

    func firstPayload() -> OnboardingAnalyticsPayload? {
        payloads.first
    }
}
