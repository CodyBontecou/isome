import CoreLocation
import Foundation
import WatchConnectivity

/// File-backed offline queue for Apple Watch route recordings. The watch writes
/// every accepted point locally first, then opportunistically transfers batches
/// to the iPhone. Batches stay queued until the phone acknowledges a successful
/// import, so recording can happen while the phone is unavailable.
final class WatchLocationSyncClient: NSObject {
    static let shared = WatchLocationSyncClient()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let stateURL: URL
    private var state: WatchLocationSyncState

    private let maxPointsPerPayload = 500
    private let liveBatchPointInterval = 25
    private let minimumTransferInterval: TimeInterval = 60

    private override init() {
        stateURL = Self.makeStateURL()
        state = Self.loadState(from: stateURL) ?? WatchLocationSyncState(deviceID: UUID())
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    @discardableResult
    func ensureActiveSession(startedAt: Date = Date()) -> UUID {
        if let activeSessionID = state.activeSessionID,
           state.sessions.contains(where: { $0.id == activeSessionID }) {
            return activeSessionID
        }

        let session = WatchLocationSyncSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: nil
        )
        state.sessions.append(session)
        state.activeSessionID = session.id
        saveState()
        syncPending(force: true)
        return session.id
    }

    func endActiveSession(endedAt: Date = Date()) {
        guard let activeSessionID = state.activeSessionID else {
            syncPending(force: true)
            return
        }

        if let index = state.sessions.firstIndex(where: { $0.id == activeSessionID }) {
            state.sessions[index].endedAt = max(state.sessions[index].startedAt, endedAt)
        }
        state.activeSessionID = nil
        saveState()
        syncPending(force: true)
    }

    func recordLocation(_ location: CLLocation) {
        let sessionID = ensureActiveSession(startedAt: location.timestamp)
        let point = WatchLocationSyncPoint(
            id: UUID(),
            sessionID: sessionID,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            altitude: location.altitude,
            speed: location.speed >= 0 ? location.speed : nil,
            horizontalAccuracy: location.horizontalAccuracy
        )

        state.points.append(point)
        saveState()

        if state.points.count % liveBatchPointInterval == 0 {
            syncPending(force: false)
        }
    }

    func syncPending(force: Bool = false) {
        guard !state.sessions.isEmpty || !state.points.isEmpty || !state.visits.isEmpty else { return }
        guard WCSession.isSupported() else { return }

        activate()

        if !force,
           let lastTransferDate = state.lastTransferDate,
           Date().timeIntervalSince(lastTransferDate) < minimumTransferInterval {
            return
        }

        guard let payload = makePayload() else { return }
        guard let payloadData = try? encoder.encode(payload) else { return }

        let selectedPointIDs = Set(payload.points.map(\.id))
        let selectedSessionIDs = Set(payload.sessions.map(\.id))
        let selectedVisitIDs = Set(payload.visits.map(\.id))
        state.pendingTransfers.append(
            WatchLocationPendingTransfer(
                sequence: payload.sequence,
                sessionIDs: selectedSessionIDs,
                pointIDs: selectedPointIDs,
                visitIDs: selectedVisitIDs,
                createdAt: payload.generatedAt
            )
        )
        state.nextSequence += 1
        state.lastTransferDate = payload.generatedAt
        saveState()

        let session = WCSession.default
        guard session.activationState == .activated else { return }

        session.transferUserInfo([
            WatchLocationSyncTransport.payloadUserInfoKey: payloadData
        ])

        if session.isReachable {
            session.sendMessageData(payloadData) { [weak self] replyData in
                DispatchQueue.main.async {
                    self?.handleAckData(replyData)
                }
            } errorHandler: { _ in
                // Durable transferUserInfo above remains queued for later delivery.
            }
        }
    }

    private func makePayload() -> WatchLocationSyncPayload? {
        let points = Array(state.points.prefix(maxPointsPerPayload))
        let visits = state.visits
        let pointSessionIDs = Set(points.map(\.sessionID))
        let activeSessionID = state.activeSessionID
        let sessions = state.sessions.filter { session in
            pointSessionIDs.contains(session.id) || session.id == activeSessionID || session.endedAt != nil || points.isEmpty
        }

        guard !sessions.isEmpty || !points.isEmpty || !visits.isEmpty else { return nil }

        return WatchLocationSyncPayload(
            deviceID: state.deviceID,
            sequence: state.nextSequence,
            isTrackingEnabled: activeSessionID != nil,
            activeSessionID: activeSessionID,
            sessions: sessions,
            points: points,
            visits: visits
        )
    }

    private func handleAckData(_ data: Data) {
        guard let ack = try? decoder.decode(WatchLocationSyncAck.self, from: data) else { return }
        handleAck(ack)
    }

    private func handleAck(_ ack: WatchLocationSyncAck) {
        guard ack.succeeded, ack.deviceID == state.deviceID else { return }
        guard let transfer = state.pendingTransfers.first(where: { $0.sequence == ack.sequence }) else {
            state.lastAckedSequence = max(state.lastAckedSequence ?? ack.sequence, ack.sequence)
            saveState()
            return
        }

        state.points.removeAll { transfer.pointIDs.contains($0.id) }
        state.visits.removeAll { visit in
            transfer.visitIDs.contains(visit.id) && visit.departedAt != nil
        }

        let remainingPointSessionIDs = Set(state.points.map(\.sessionID))
        state.sessions.removeAll { session in
            guard transfer.sessionIDs.contains(session.id) else { return false }
            guard session.endedAt != nil else { return false }
            return !remainingPointSessionIDs.contains(session.id)
        }

        state.pendingTransfers.removeAll { $0.sequence <= ack.sequence }
        state.lastAckedSequence = max(state.lastAckedSequence ?? ack.sequence, ack.sequence)
        saveState()

        if !state.points.isEmpty || state.sessions.contains(where: { $0.endedAt != nil }) || state.visits.contains(where: { $0.departedAt != nil }) {
            syncPending(force: true)
        }
    }

    private func saveState() {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            // Keep the in-memory queue alive for this process; retry on the next save.
        }
    }

    private static func loadState(from url: URL) -> WatchLocationSyncState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WatchLocationSyncState.self, from: data)
    }

    private static func makeStateURL() -> URL {
        let baseURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedLocationData.appGroupIdentifier
        ) ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        return baseURL
            .appendingPathComponent("WatchLocationSync", isDirectory: true)
            .appendingPathComponent("state.json")
    }
}

extension WatchLocationSyncClient: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated, error == nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.syncPending(force: true)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        DispatchQueue.main.async { [weak self] in
            self?.syncPending(force: true)
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        DispatchQueue.main.async { [weak self] in
            self?.handleAckData(messageData)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchLocationSyncTransport.ackUserInfoKey] as? Data else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handleAckData(data)
        }
    }
}

private struct WatchLocationSyncState: Codable {
    var deviceID: UUID
    var nextSequence: Int = 1
    var sessions: [WatchLocationSyncSession] = []
    var points: [WatchLocationSyncPoint] = []
    var visits: [WatchLocationSyncVisit] = []
    var activeSessionID: UUID?
    var pendingTransfers: [WatchLocationPendingTransfer] = []
    var lastTransferDate: Date?
    var lastAckedSequence: Int?

    init(deviceID: UUID) {
        self.deviceID = deviceID
    }

    private enum CodingKeys: String, CodingKey {
        case deviceID
        case nextSequence
        case sessions
        case points
        case visits
        case activeSessionID
        case pendingTransfers
        case lastTransferDate
        case lastAckedSequence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(UUID.self, forKey: .deviceID)
        nextSequence = try container.decodeIfPresent(Int.self, forKey: .nextSequence) ?? 1
        sessions = try container.decodeIfPresent([WatchLocationSyncSession].self, forKey: .sessions) ?? []
        points = try container.decodeIfPresent([WatchLocationSyncPoint].self, forKey: .points) ?? []
        visits = try container.decodeIfPresent([WatchLocationSyncVisit].self, forKey: .visits) ?? []
        activeSessionID = try container.decodeIfPresent(UUID.self, forKey: .activeSessionID)
        pendingTransfers = try container.decodeIfPresent([WatchLocationPendingTransfer].self, forKey: .pendingTransfers) ?? []
        lastTransferDate = try container.decodeIfPresent(Date.self, forKey: .lastTransferDate)
        lastAckedSequence = try container.decodeIfPresent(Int.self, forKey: .lastAckedSequence)
    }
}

private struct WatchLocationPendingTransfer: Codable {
    var sequence: Int
    var sessionIDs: Set<UUID>
    var pointIDs: Set<UUID>
    var visitIDs: Set<UUID>
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case sequence
        case sessionIDs
        case pointIDs
        case visitIDs
        case createdAt
    }

    init(sequence: Int, sessionIDs: Set<UUID>, pointIDs: Set<UUID>, visitIDs: Set<UUID>, createdAt: Date) {
        self.sequence = sequence
        self.sessionIDs = sessionIDs
        self.pointIDs = pointIDs
        self.visitIDs = visitIDs
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sequence = try container.decode(Int.self, forKey: .sequence)
        sessionIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .sessionIDs) ?? []
        pointIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .pointIDs) ?? []
        visitIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .visitIDs) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
