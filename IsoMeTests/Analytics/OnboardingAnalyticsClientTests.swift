//
//  OnboardingAnalyticsClientTests.swift
//  IsoMeTests
//
//  Tests for the offline-safe onboarding analytics client.
//

import XCTest
@testable import IsoMe

final class OnboardingAnalyticsClientTests: XCTestCase {

    func testTrackDoesNotThrowOrPropagateOfflineTransportFailures() async {
        let transport = RecordingOnboardingAnalyticsTransport(error: URLError(.notConnectedToInternet))
        let defaults = FakeUserDefaults()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: defaults,
            queueKey: "onboarding.analytics.test.offline",
            maxQueueSize: 3,
            isEnabled: true
        )

        client.track(Self.event(buildNumber: "1"))
        await client.flushAndWait()

        let attemptCount = await transport.attemptCountValue()
        let sentPayloads = await transport.payloadsValue()
        let queuedPayloads = await client.queuedPayloads()
        let queuedPayload = try? XCTUnwrap(queuedPayloads.first)
        XCTAssertEqual(attemptCount, 1)
        XCTAssertEqual(queuedPayloads.count, 1)
        XCTAssertNotNil(queuedPayload?.eventId)
        XCTAssertEqual(queuedPayload?.eventId, sentPayloads.first?.eventId)
        XCTAssertEqual(queuedPayload?.eventName, Self.event(buildNumber: "1").encodedPayload().eventName)
        XCTAssertEqual(queuedPayload?.properties, Self.event(buildNumber: "1").encodedPayload().properties)
    }

    func testUITestOfflineTransportHookFailsSoftlyForRegressionScenarios() async {
        let transport = OnboardingAnalyticsTransportFactory.makeDefaultTransport(
            environment: ["UITEST_ANALYTICS_TRANSPORT": "offline"]
        )

        do {
            try await transport.send(Self.event(buildNumber: "1").encodedPayload())
            XCTFail("Offline UI-test transport should simulate network failure.")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDefaultTransportUsesDeployedCloudflareEndpointWhenOfflineHookIsAbsent() {
        let transport = OnboardingAnalyticsTransportFactory.makeDefaultTransport(
            environment: [:],
            defaults: FakeUserDefaults()
        )
        XCTAssertTrue(transport is CloudflareOnboardingAnalyticsTransport)
    }

    func testDefaultTransportUsesCloudflareWhenEndpointIsConfigured() {
        let transport = OnboardingAnalyticsTransportFactory.makeDefaultTransport(
            environment: ["ONBOARDING_ANALYTICS_ENDPOINT_URL": "https://onboarding.example.workers.dev"],
            defaults: FakeUserDefaults()
        )

        XCTAssertTrue(transport is CloudflareOnboardingAnalyticsTransport)
    }

    func testDefaultTransportFallsBackToDeployedCloudflareEndpointWhenConfigIsPlaceholder() {
        let transport = OnboardingAnalyticsTransportFactory.makeDefaultTransport(
            environment: ["ONBOARDING_ANALYTICS_ENDPOINT_URL": "$(ONBOARDING_ANALYTICS_ENDPOINT_URL)"],
            defaults: FakeUserDefaults()
        )

        XCTAssertTrue(transport is CloudflareOnboardingAnalyticsTransport)
    }

    func testOnboardingAnalyticsInstallIDIsStableAndAnonymous() {
        let defaults = FakeUserDefaults()
        let store = OnboardingAnalyticsInstallIDStore(defaults: defaults)

        let first = store.installID()
        let second = store.installID()

        XCTAssertEqual(first, second)
        XCTAssertNotNil(UUID(uuidString: first))
        XCTAssertFalse(first.localizedCaseInsensitiveContains("location"))
        XCTAssertFalse(first.localizedCaseInsensitiveContains("address"))
        XCTAssertFalse(first.localizedCaseInsensitiveContains("file"))
    }

    func testSlowTransportDoesNotBlockCallerPath() async {
        let transport = BlockingOnboardingAnalyticsTransport()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.slow",
            maxQueueSize: 3,
            isEnabled: true
        )

        let start = Date()
        client.track(Self.event(buildNumber: "1"))
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 0.05, "track(_:) must return before slow network transport completes.")
        await transport.waitForAttempt()
        await transport.release()
        await client.flushAndWait()
        let queuedPayloads = await client.queuedPayloads()
        XCTAssertEqual(queuedPayloads, [])
    }

    func testQueuedPayloadsAreSanitizedBeforePersistence() async throws {
        let defaults = FakeUserDefaults()
        let client = OnboardingAnalyticsClient(
            transport: RecordingOnboardingAnalyticsTransport(error: URLError(.notConnectedToInternet)),
            defaults: defaults,
            queueKey: "onboarding.analytics.test.sanitized",
            maxQueueSize: 3,
            isEnabled: true
        )

        client.track(OnboardingAnalyticsEvent(
            name: .onboardingStarted,
            properties: OnboardingAnalyticsProperties(
                appVersion: "2026-05-14",
                buildNumber: "build 42",
                platform: .iOS,
                onboardingStep: .welcome
            )
        ))
        await client.flushAndWait()

        let data = try XCTUnwrap(defaults.data(forKey: "onboarding.analytics.test.sanitized"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let persisted = try XCTUnwrap(json.first)
        let properties = try XCTUnwrap(persisted["properties"] as? [String: Any])

        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(persisted["eventId"] as? String)))
        XCTAssertEqual(persisted["eventName"] as? String, "onboarding_started")
        XCTAssertEqual(properties["platform"] as? String, "ios")
        XCTAssertEqual(properties["onboardingStep"] as? String, "welcome")
        XCTAssertNil(properties["appVersion"])
        XCTAssertNil(properties["buildNumber"])
        XCTAssertFalse(properties.keys.contains("latitude"))
        XCTAssertFalse(properties.keys.contains("longitude"))
        XCTAssertFalse(properties.keys.contains("address"))
        XCTAssertFalse(properties.keys.contains("filePath"))
        XCTAssertFalse(properties.keys.contains("webhookURL"))
    }

    func testQueueIsCappedAndDropsOldestPayloads() async {
        let client = OnboardingAnalyticsClient(
            transport: RecordingOnboardingAnalyticsTransport(error: URLError(.notConnectedToInternet)),
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.cap",
            maxQueueSize: 2,
            isEnabled: true
        )

        client.track(Self.event(buildNumber: "1"))
        client.track(Self.event(buildNumber: "2"))
        client.track(Self.event(buildNumber: "3"))
        await client.flushAndWait()

        let queuedPayloads = await client.queuedPayloads()
        let queuedBuilds = queuedPayloads.compactMap { payload -> String? in
            guard case let .string(value) = payload.properties[.buildNumber] else { return nil }
            return value
        }

        XCTAssertEqual(queuedBuilds, ["2", "3"])
        XCTAssertTrue(queuedPayloads.allSatisfy { payload in
            guard let eventId = payload.eventId else { return false }
            return UUID(uuidString: eventId) != nil
        })
    }

    func testQueuedPayloadsRetryAfterTransientTransportFailureWithoutAdditionalTrack() async {
        let transport = FlakyOnboardingAnalyticsTransport(failuresBeforeSuccess: 1)
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: FakeUserDefaults(),
            queueKey: "onboarding.analytics.test.retry",
            maxQueueSize: 3,
            isEnabled: true,
            retryDelayNanoseconds: 1_000_000
        )

        client.track(Self.event(buildNumber: "1"))

        for _ in 0..<100 {
            if await transport.attemptCountValue() >= 2 { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        let attemptCount = await transport.attemptCountValue()
        let queuedPayloads = await client.queuedPayloads()
        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(queuedPayloads, [])
    }

    func testDisabledModeRecordsNoTransportAttemptsAndDoesNotPersistQueue() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let defaults = FakeUserDefaults()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: defaults,
            queueKey: "onboarding.analytics.test.disabled",
            maxQueueSize: 3,
            isEnabled: false
        )

        client.track(Self.event(buildNumber: "1"))
        await client.flushAndWait()

        let attemptCount = await transport.attemptCountValue()
        let queuedPayloads = await client.queuedPayloads()
        XCTAssertEqual(attemptCount, 0)
        XCTAssertNil(defaults.data(forKey: "onboarding.analytics.test.disabled"))
        XCTAssertEqual(queuedPayloads, [])
    }

    func testDefaultDebugModeIsDisabledUnlessOverridden() async {
        let transport = RecordingOnboardingAnalyticsTransport()
        let defaults = FakeUserDefaults()
        let client = OnboardingAnalyticsClient(
            transport: transport,
            defaults: defaults,
            queueKey: "onboarding.analytics.test.default-debug",
            maxQueueSize: 3
        )

        client.track(Self.event(buildNumber: "1"))
        await client.flushAndWait()

        let attemptCount = await transport.attemptCountValue()
        XCTAssertEqual(attemptCount, 0)
        XCTAssertNil(defaults.data(forKey: "onboarding.analytics.test.default-debug"))
    }

    private static func event(buildNumber: String) -> OnboardingAnalyticsEvent {
        OnboardingAnalyticsEvent(
            name: .onboardingStepViewed,
            properties: OnboardingAnalyticsProperties(
                appVersion: "1.0",
                buildNumber: buildNumber,
                platform: .iOS,
                onboardingStep: .welcome,
                authorizationStatus: .notDetermined
            )
        )
    }
}

private actor RecordingOnboardingAnalyticsTransport: OnboardingAnalyticsTransport {
    private let error: Error?
    private(set) var payloads: [OnboardingAnalyticsPayload] = []
    private(set) var attemptCount = 0

    init(error: Error? = nil) {
        self.error = error
    }

    func send(_ payload: OnboardingAnalyticsPayload) async throws {
        attemptCount += 1
        payloads.append(payload)
        if let error {
            throw error
        }
    }

    func attemptCountValue() -> Int {
        attemptCount
    }

    func payloadsValue() -> [OnboardingAnalyticsPayload] {
        payloads
    }
}

private actor FlakyOnboardingAnalyticsTransport: OnboardingAnalyticsTransport {
    private var failuresRemaining: Int
    private(set) var attemptCount = 0

    init(failuresBeforeSuccess: Int) {
        self.failuresRemaining = failuresBeforeSuccess
    }

    func send(_ payload: OnboardingAnalyticsPayload) async throws {
        attemptCount += 1
        guard failuresRemaining > 0 else { return }

        failuresRemaining -= 1
        throw URLError(.networkConnectionLost)
    }

    func attemptCountValue() -> Int {
        attemptCount
    }
}

private actor BlockingOnboardingAnalyticsTransport: OnboardingAnalyticsTransport {
    private var attemptContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var hasAttempted = false
    private var isReleased = false

    func send(_ payload: OnboardingAnalyticsPayload) async throws {
        hasAttempted = true
        attemptContinuation?.resume()
        attemptContinuation = nil

        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitForAttempt() async {
        guard !hasAttempted else { return }
        await withCheckedContinuation { continuation in
            attemptContinuation = continuation
        }
    }

    func release() {
        isReleased = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
