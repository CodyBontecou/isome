import XCTest
@testable import IsoMe

/// Tests for the security- and correctness-sensitive parts of WebhookManager:
/// keychain round-trip, the one-time UserDefaults → Keychain migration, and
/// the error-message sanitization that prevents API keys from leaking into
/// persisted error logs.
@MainActor
final class WebhookManagerTests: XCTestCase {

    private let testAccount = "webhook.tests.authValue"
    private let testLegacyKey = "webhook.tests.authValue"

    override func setUp() {
        super.setUp()
        WebhookManager.keychainWriteString("", account: testAccount)
        UserDefaults.standard.removeObject(forKey: testLegacyKey)
    }

    override func tearDown() {
        WebhookManager.keychainWriteString("", account: testAccount)
        UserDefaults.standard.removeObject(forKey: testLegacyKey)
        super.tearDown()
    }

    // MARK: - Keychain round-trip

    func testKeychainWriteThenReadReturnsSameValue() {
        WebhookManager.keychainWriteString("supersecret", account: testAccount)
        XCTAssertEqual(WebhookManager.keychainReadString(account: testAccount), "supersecret")
    }

    func testKeychainReadMissingReturnsNil() {
        XCTAssertNil(WebhookManager.keychainReadString(account: testAccount))
    }

    func testKeychainEmptyValueDeletes() {
        WebhookManager.keychainWriteString("first", account: testAccount)
        XCTAssertNotNil(WebhookManager.keychainReadString(account: testAccount))

        WebhookManager.keychainWriteString("", account: testAccount)
        XCTAssertNil(WebhookManager.keychainReadString(account: testAccount),
                     "Empty string must remove the keychain entry")
    }

    func testKeychainUpdateOverwritesPriorValue() {
        WebhookManager.keychainWriteString("first", account: testAccount)
        WebhookManager.keychainWriteString("second", account: testAccount)
        XCTAssertEqual(WebhookManager.keychainReadString(account: testAccount), "second")
    }

    func testKeychainHandlesUnicodeAndLongStrings() {
        let value = String(repeating: "🔐", count: 200) + "·secret·" + String(repeating: "x", count: 1000)
        WebhookManager.keychainWriteString(value, account: testAccount)
        XCTAssertEqual(WebhookManager.keychainReadString(account: testAccount), value)
    }

    // MARK: - loadCredential migration

    func testLoadCredentialReturnsKeychainValueWhenPresent() {
        WebhookManager.keychainWriteString("from-keychain", account: testAccount)
        UserDefaults.standard.set("from-defaults", forKey: testLegacyKey)

        let value = WebhookManager.loadCredential(
            account: testAccount,
            legacyKey: testLegacyKey,
            defaultValue: "fallback"
        )

        XCTAssertEqual(value, "from-keychain", "Keychain takes precedence over UserDefaults")
        XCTAssertEqual(UserDefaults.standard.string(forKey: testLegacyKey), "from-defaults",
                       "When keychain is already populated, UserDefaults is left alone")
    }

    func testLoadCredentialMigratesFromUserDefaults() {
        UserDefaults.standard.set("legacy-secret", forKey: testLegacyKey)

        let value = WebhookManager.loadCredential(
            account: testAccount,
            legacyKey: testLegacyKey,
            defaultValue: "fallback"
        )

        XCTAssertEqual(value, "legacy-secret")
        XCTAssertEqual(WebhookManager.keychainReadString(account: testAccount), "legacy-secret",
                       "Migrated value must be in Keychain")
        XCTAssertNil(UserDefaults.standard.string(forKey: testLegacyKey),
                     "Plaintext UserDefaults copy must be deleted after migration")
    }

    func testLoadCredentialReturnsDefaultWhenNothingStored() {
        let value = WebhookManager.loadCredential(
            account: testAccount,
            legacyKey: testLegacyKey,
            defaultValue: "fallback"
        )
        XCTAssertEqual(value, "fallback")
        XCTAssertNil(WebhookManager.keychainReadString(account: testAccount),
                     "Default fallback must not be persisted to Keychain")
    }

    func testLoadCredentialIgnoresEmptyLegacyValue() {
        UserDefaults.standard.set("", forKey: testLegacyKey)

        let value = WebhookManager.loadCredential(
            account: testAccount,
            legacyKey: testLegacyKey,
            defaultValue: "fallback"
        )

        XCTAssertEqual(value, "fallback", "Empty legacy string is not a credential")
        XCTAssertNil(WebhookManager.keychainReadString(account: testAccount))
    }

    func testLoadCredentialMigrationIsIdempotent() {
        UserDefaults.standard.set("once", forKey: testLegacyKey)

        let first = WebhookManager.loadCredential(
            account: testAccount,
            legacyKey: testLegacyKey,
            defaultValue: "fallback"
        )
        let second = WebhookManager.loadCredential(
            account: testAccount,
            legacyKey: testLegacyKey,
            defaultValue: "fallback"
        )

        XCTAssertEqual(first, "once")
        XCTAssertEqual(second, "once")
        XCTAssertNil(UserDefaults.standard.string(forKey: testLegacyKey))
    }

    // MARK: - KeychainKey account naming

    /// The Keychain account names are part of the on-device data contract —
    /// changing them silently would orphan every existing user's credentials.
    func testKeychainAccountNamesAreStable() {
        XCTAssertEqual(WebhookManager.keychainAccount(.authKey), "webhook.authKey")
        XCTAssertEqual(WebhookManager.keychainAccount(.authValue), "webhook.authValue")
        XCTAssertEqual(WebhookManager.keychainAccount(.authUsername), "webhook.authUsername")
    }

    func testLegacyDefaultsKeysMatchOriginalNames() {
        XCTAssertEqual(WebhookManager.legacyDefaultsKey(.authKey), "webhook.authKey")
        XCTAssertEqual(WebhookManager.legacyDefaultsKey(.authValue), "webhook.authValue")
        XCTAssertEqual(WebhookManager.legacyDefaultsKey(.authUsername), "webhook.authUsername")
    }

    // MARK: - Error sanitization

    func testSanitizeReplacesSecretWithMask() {
        let scrubbed = WebhookManager.sanitizeError(
            "Failed to load https://api.example.com?api_key=hunter2",
            masking: "hunter2"
        )
        XCTAssertEqual(scrubbed, "Failed to load https://api.example.com?api_key=***")
    }

    func testSanitizeReplacesAllOccurrences() {
        let scrubbed = WebhookManager.sanitizeError(
            "tried hunter2, then hunter2 again",
            masking: "hunter2"
        )
        XCTAssertEqual(scrubbed, "tried ***, then *** again")
    }

    func testSanitizeNoOpWhenSecretEmpty() {
        let message = "some error: token=abc"
        XCTAssertEqual(WebhookManager.sanitizeError(message, masking: ""), message)
    }

    func testSanitizeNoOpWhenSecretAbsent() {
        let message = "the request timed out"
        XCTAssertEqual(WebhookManager.sanitizeError(message, masking: "hunter2"), message)
    }

    func testSanitizeHandlesSpecialCharacterSecrets() {
        let secret = "a+b/c=d&e?f"
        let scrubbed = WebhookManager.sanitizeError(
            "url contains a+b/c=d&e?f in the query",
            masking: secret
        )
        XCTAssertEqual(scrubbed, "url contains *** in the query")
    }

    // MARK: - Delivery, errors, and retry

    func testFormatFromTokenRestoresEveryPersistedFormat() {
        XCTAssertEqual(WebhookManager.formatFromToken("json").token, "json")
        XCTAssertEqual(WebhookManager.formatFromToken("csv").token, "csv")
        XCTAssertEqual(WebhookManager.formatFromToken("md").token, "md")
        XCTAssertEqual(WebhookManager.formatFromToken("markdown").token, "md")
        XCTAssertEqual(WebhookManager.formatFromToken("owntracks").token, "owntracks")
        XCTAssertEqual(WebhookManager.formatFromToken("overland").token, "overland")
        XCTAssertEqual(WebhookManager.formatFromToken("gpx").token, "gpx")
        XCTAssertEqual(WebhookManager.formatFromToken("geojson").token, "geojson")
    }

    func testWebhookSendPostsBodyHeadersAndAuthQuery() async throws {
        let manager = WebhookManager.shared
        manager.configureForTesting(urlSession: makeMockSession(statusCode: 202) { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/geo+json")
            XCTAssertEqual(request.url?.query, "token=abc123")
            XCTAssertNotNil(request.httpBodyStream ?? request.httpBody)
        })
        manager.urlString = "https://webhooks.example.test/ingest"
        manager.format = .geojson
        manager.authType = .apiKeyQuery
        manager.authKey = "token"
        manager.authValue = "abc123"

        try await manager.sendPointsForTesting([makePoint()])

        XCTAssertNil(manager.lastError)
        XCTAssertNotNil(manager.lastSentAt)
    }

    func testWebhookSendThrowsHTTPErrorForServerFailure() async throws {
        let manager = WebhookManager.shared
        manager.configureForTesting(urlSession: makeMockSession(statusCode: 500))
        manager.urlString = "https://webhooks.example.test/ingest"
        manager.format = .json
        manager.authType = .none

        do {
            try await manager.sendPointsForTesting([makePoint()])
            XCTFail("Expected HTTP 500 to fail delivery")
        } catch let error as WebhookError {
            XCTAssertEqual(error.localizedDescription, "Server returned HTTP 500")
        }
    }

    func testFlushBatchRetriesByKeepingQueuedPointsOnFailure() async {
        let manager = WebhookManager.shared
        manager.configureForTesting(urlSession: makeMockSession(statusCode: 503))
        manager.urlString = "https://webhooks.example.test/ingest"
        manager.format = .owntracks
        manager.authType = .none
        manager.enqueueForTesting([makePoint(), makePoint(offset: 60)])

        await manager.flushBatch()

        XCTAssertEqual(manager.queuedPointCount, 2)
        XCTAssertEqual(manager.lastError, "Server returned HTTP 503")
    }

    private func makeMockSession(
        statusCode: Int,
        assertRequest: ((URLRequest) -> Void)? = nil
    ) -> URLSession {
        WebhookMockURLProtocol.handler = { request in
            assertRequest?(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data("{}".utf8), response)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WebhookMockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makePoint(offset: TimeInterval = 0) -> LocationPoint {
        LocationPoint(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: Date(timeIntervalSince1970: 1_778_411_400 + offset),
            altitude: 10,
            speed: 2,
            horizontalAccuracy: 5
        )
    }
}

private final class WebhookMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Data, URLResponse))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: WebhookError.httpError(0))
            return
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
