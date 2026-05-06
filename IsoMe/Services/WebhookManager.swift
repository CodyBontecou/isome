import Foundation
import Combine
import SwiftData

/// HTTP webhook delivery of location data to a user-configured endpoint.
///
/// Supports OwnTracks, Overland, GPX, JSON, CSV, and Markdown payload formats.
/// Multiple auth methods (none, API key query param, Bearer, Basic, custom header).
/// Multiple send modes (realtime per-point, batch count, batch time, manual).
///
/// Privacy: entirely opt-in, disabled by default. When enabled, a prominent
/// warning tells the user their location data will be sent off-device.
@MainActor
final class WebhookManager: ObservableObject {
    static let shared = WebhookManager()

    // MARK: - Auth types

    enum AuthType: String, CaseIterable, Identifiable {
        case none
        case apiKeyQuery
        case bearer
        case basic
        case customHeader

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "NONE"
            case .apiKeyQuery: return "API KEY (QUERY)"
            case .bearer: return "BEARER TOKEN"
            case .basic: return "BASIC AUTH"
            case .customHeader: return "CUSTOM HEADER"
            }
        }
    }

    enum SendMode: String, CaseIterable, Identifiable {
        case realtime
        case batchCount
        case batchTime
        case manual

        var id: String { rawValue }

        var label: String {
            switch self {
            case .realtime: return "REAL-TIME"
            case .batchCount: return "BY COUNT"
            case .batchTime: return "BY TIME"
            case .manual: return "MANUAL"
            }
        }
    }

    // MARK: - Published state

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.key(.enabled)); syncObservation() }
    }
    @Published var urlString: String {
        didSet { defaults.set(urlString, forKey: Self.key(.url)) }
    }
    @Published var format: ExportFormat {
        didSet { defaults.set(format.token, forKey: Self.key(.format)) }
    }
    @Published var authType: AuthType {
        didSet { defaults.set(authType.rawValue, forKey: Self.key(.authType)) }
    }
    @Published var authKey: String {
        didSet { defaults.set(authKey, forKey: Self.key(.authKey)) }
    }
    @Published var authValue: String {
        didSet { defaults.set(authValue, forKey: Self.key(.authValue)) }
    }
    @Published var authUsername: String {
        didSet { defaults.set(authUsername, forKey: Self.key(.authUsername)) }
    }
    @Published var sendMode: SendMode {
        didSet { defaults.set(sendMode.rawValue, forKey: Self.key(.sendMode)); syncObservation() }
    }
    @Published var batchCount: Int {
        didSet { defaults.set(batchCount, forKey: Self.key(.batchCount)) }
    }
    @Published var batchTimeMinutes: Int {
        didSet { defaults.set(batchTimeMinutes, forKey: Self.key(.batchTimeMinutes)); syncTimer() }
    }
    @Published var includeVisits: Bool {
        didSet { defaults.set(includeVisits, forKey: Self.key(.includeVisits)) }
    }

    @Published private(set) var lastSentAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var queuedPointCount: Int = 0
    @Published private(set) var isSending: Bool = false

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var flushTimer: Timer?
    private var pendingPoints: [LocationPoint] = []
    private weak var modelContainer: ModelContainer?
    private var urlSession: URLSession!

    private enum DefaultsKey: String {
        case enabled, url, format, authType, authKey, authValue, authUsername
        case sendMode, batchCount, batchTimeMinutes, includeVisits
        case lastSentAt, lastError
    }

    private static func key(_ k: DefaultsKey) -> String { "webhook.\(k.rawValue)" }

    private init() {
        let d = defaults
        self.isEnabled = d.bool(forKey: Self.key(.enabled))
        self.urlString = d.string(forKey: Self.key(.url)) ?? ""
        self.format = Self.formatFromToken(d.string(forKey: Self.key(.format)))
        self.authType = AuthType(rawValue: d.string(forKey: Self.key(.authType)) ?? "") ?? .none
        self.authKey = d.string(forKey: Self.key(.authKey)) ?? "api_key"
        self.authValue = d.string(forKey: Self.key(.authValue)) ?? ""
        self.authUsername = d.string(forKey: Self.key(.authUsername)) ?? ""
        self.sendMode = SendMode(rawValue: d.string(forKey: Self.key(.sendMode)) ?? "") ?? .realtime
        self.batchCount = d.object(forKey: Self.key(.batchCount)) as? Int ?? 10
        self.batchTimeMinutes = d.object(forKey: Self.key(.batchTimeMinutes)) as? Int ?? 5
        self.includeVisits = d.object(forKey: Self.key(.includeVisits)) as? Bool ?? true
        self.lastSentAt = d.object(forKey: Self.key(.lastSentAt)) as? Date
        self.lastError = d.string(forKey: Self.key(.lastError))

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: config)

        syncTimer()
    }

    // MARK: - Wiring

    /// Must be called once on app launch so the manager can observe location updates.
    func attach(modelContainer: ModelContainer, locationManager: LocationManager) {
        self.modelContainer = modelContainer
        syncObservation(locationManager: locationManager)
    }

    private func syncObservation(locationManager: LocationManager? = nil) {
        cancellables.removeAll()
        guard isEnabled else { return }

        guard let lm = locationManager ?? LocationManager.shared else { return }

        if sendMode == .realtime {
            lm.$locationPointsSavedCount
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    Task { @MainActor in
                        await self?.onNewPoint(locationManager: lm)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func syncTimer() {
        flushTimer?.invalidate()
        flushTimer = nil
        guard isEnabled, sendMode == .batchTime, batchTimeMinutes > 0 else { return }
        flushTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(batchTimeMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in await self?.flushBatch() }
        }
    }

    // MARK: - Sending

    private func onNewPoint(locationManager: LocationManager) async {
        guard let context = modelContainer?.mainContext else { return }
        do {
            var descriptor = FetchDescriptor<LocationPoint>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            descriptor.fetchLimit = 1
            let points = try context.fetch(descriptor)
            guard let latest = points.first else { return }

            if latest.isOutlier && !UserDefaults.standard.bool(forKey: "showOutliers") {
                return
            }

            switch sendMode {
            case .realtime:
                try await sendPoints([latest])
            case .batchCount:
                pendingPoints.append(latest)
                queuedPointCount = pendingPoints.count
                if pendingPoints.count >= batchCount {
                    await flushBatch()
                }
            case .batchTime:
                pendingPoints.append(latest)
                queuedPointCount = pendingPoints.count
            case .manual:
                break
            }
        } catch {
            recordError(error.localizedDescription)
        }
    }

    /// Send all currently queued points (batch flush).
    func flushBatch() async {
        guard !pendingPoints.isEmpty else { return }
        let batch = pendingPoints
        pendingPoints.removeAll()
        do {
            try await sendPoints(batch)
            queuedPointCount = pendingPoints.count
        } catch {
            pendingPoints.insert(contentsOf: batch, at: 0)
            queuedPointCount = pendingPoints.count
            recordError(error.localizedDescription)
        }
    }

    /// Send a manual export of all saved data.
    func sendNow() async {
        guard let context = modelContainer?.mainContext else { return }
        do {
            let visits = includeVisits ? (try context.fetch(FetchDescriptor<Visit>())) : []
            let points = try context.fetch(FetchDescriptor<LocationPoint>())
            try await sendPoints(points, visits: visits)
        } catch {
            recordError(error.localizedDescription)
        }
    }

    /// Test the configured endpoint with a minimal payload.
    func testConnection() async throws -> String {
        let testPayload = """
        {"_type":"location","lat":0,"lon":0,"tst":\(Int(Date().timeIntervalSince1970)),"tid":"IM","topic":"owntracks/test/iso.me"}
        """
        guard let url = buildURL() else {
            throw WebhookError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = testPayload.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iso.me/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        applyAuth(to: &request)

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebhookError.httpError(0)
        }
        if (200...299).contains(httpResponse.statusCode) {
            return "Connected (HTTP \(httpResponse.statusCode))"
        } else if httpResponse.statusCode == 401 {
            throw WebhookError.unauthorized
        } else {
            throw WebhookError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Core send

    private func sendPoints(_ points: [LocationPoint], visits: [Visit] = []) async throws {
        guard !points.isEmpty else { return }
        guard let url = buildURL() else {
            throw WebhookError.invalidURL
        }

        isSending = true
        defer { isSending = false }

        let body = try formatPayload(points: points, visits: visits)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(format.mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("iso.me/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        applyAuth(to: &request)

        let (_, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WebhookError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        lastSentAt = Date()
        defaults.set(lastSentAt, forKey: Self.key(.lastSentAt))
        lastError = nil
        defaults.removeObject(forKey: Self.key(.lastError))
    }

    // MARK: - URL building

    private func buildURL() -> URL? {
        guard !urlString.isEmpty else { return nil }
        var urlStr = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if authType == .apiKeyQuery, !authKey.isEmpty, !authValue.isEmpty {
            let separator = urlStr.contains("?") ? "&" : "?"
            let encodedKey = authKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? authKey
            let encodedValue = authValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? authValue
            urlStr += "\(separator)\(encodedKey)=\(encodedValue)"
        }

        return URL(string: urlStr)
    }

    // MARK: - Auth

    private func applyAuth(to request: inout URLRequest) {
        switch authType {
        case .none, .apiKeyQuery:
            break
        case .bearer:
            if !authValue.isEmpty {
                request.setValue("Bearer \(authValue)", forHTTPHeaderField: "Authorization")
            }
        case .basic:
            if !authUsername.isEmpty || !authValue.isEmpty {
                let login = "\(authUsername):\(authValue)"
                if let encoded = login.data(using: .utf8)?.base64EncodedString() {
                    request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
                }
            }
        case .customHeader:
            if !authKey.isEmpty, !authValue.isEmpty {
                request.setValue(authValue, forHTTPHeaderField: authKey)
            }
        }
    }

    // MARK: - Payload formatting

    private func formatPayload(points: [LocationPoint], visits: [Visit] = []) throws -> Data {
        let hasVisits = !visits.isEmpty
        switch format {
        case .owntracks:
            return try ExportService.exportLocationPointsToOwnTracks(points: points)
        case .overland:
            return try ExportService.exportLocationPointsToOverland(points: points)
        case .json:
            if hasVisits {
                return try ExportService.exportCombinedToJSON(visits: visits, points: points)
            }
            return try ExportService.exportLocationPointsToJSON(points: points)
        case .csv:
            if hasVisits {
                return ExportService.exportCombinedToCSV(visits: visits, points: points)
            }
            return ExportService.exportLocationPointsToCSV(points: points)
        case .markdown:
            if hasVisits {
                return ExportService.exportCombinedToMarkdown(visits: visits, points: points)
            }
            return ExportService.exportLocationPointsToMarkdown(points: points)
        case .gpx:
            if hasVisits {
                return ExportService.exportCombinedToGPX(visits: visits, points: points)
            }
            return ExportService.exportLocationPointsToGPX(points: points)
        }
    }

    // MARK: - Helpers

    private func recordError(_ message: String) {
        lastError = message
        defaults.set(message, forKey: Self.key(.lastError))
    }

    static func formatFromToken(_ token: String?) -> ExportFormat {
        switch token {
        case "csv": return .csv
        case "md", "markdown": return .markdown
        case "owntracks": return .owntracks
        case "overland": return .overland
        case "gpx": return .gpx
        default: return .json
        }
    }
}

// MARK: - Errors

enum WebhookError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code):
            return "Server returned HTTP \(code)"
        case .unauthorized:
            return "Unauthorized (HTTP 401). Check your credentials."
        }
    }
}
