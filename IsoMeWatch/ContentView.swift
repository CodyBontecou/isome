import SwiftUI
import WatchConnectivity
import WidgetKit

struct ContentView: View {
    @State private var locationData: SharedLocationData = .empty
    @StateObject private var commandSender = WatchManualVisitCommandSender()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tracking Status Header
                trackingStatusView

                Divider()

                // Today's Stats
                statsView

                if let locationName = locationData.currentLocationName {
                    Divider()
                    currentLocationView(locationName)
                }

                if locationData.isManualCheckInOpen {
                    Divider()
                    manualCheckInView
                }

                Divider()
                manualActionsView
            }
            .padding()
        }
        .onAppear {
            commandSender.activate()
            refreshData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedLocationDataDidUpdate)) { _ in
            refreshData()
        }
    }

    private var trackingStatusView: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.largeTitle)
                .foregroundStyle(statusColor)

            Text(locationData.trackingStatus)
                .font(.headline)

            if locationData.isTrackingEnabled,
               let remaining = locationData.formattedRemainingTime {
                Text("\(remaining) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statsView: some View {
        VStack(spacing: 12) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                statItem(value: "\(locationData.todayVisitsCount)", label: "Visits", icon: "mappin.circle")
                statItem(value: locationData.formattedDistance, label: "Distance", icon: "figure.walk")
            }

            if locationData.todayPointsCount > 0 {
                statItem(value: "\(locationData.todayPointsCount)", label: "Points", icon: "location.fill")
            }
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func currentLocationView(_ name: String) -> some View {
        VStack(spacing: 4) {
            Text("Current Location")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.subheadline)
                .multilineTextAlignment(.center)
        }
    }

    private var manualCheckInView: some View {
        VStack(spacing: 4) {
            Text("Manual Check-In")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(locationData.openManualVisitDisplayName)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            if let arrivedAt = locationData.openManualVisitArrivedAt {
                Text(arrivedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var manualActionsView: some View {
        VStack(spacing: 8) {
            Button {
                commandSender.send(locationData.isManualCheckInOpen ? .checkOut : .checkIn)
            } label: {
                Label(
                    locationData.isManualCheckInOpen ? "Check Out" : "Check In",
                    systemImage: locationData.isManualCheckInOpen ? "checkmark.circle" : "mappin.and.ellipse"
                )
            }
            .disabled(commandSender.isSending)

            if let statusMessage = commandSender.statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(commandSender.lastResponseSucceeded == false ? .red : .secondary)
                    .multilineTextAlignment(.center)
            }

            if commandSender.queuedCommandCount > 0 {
                Text("\(commandSender.queuedCommandCount) queued")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        if locationData.isManualCheckInOpen { return "checkmark.circle.fill" }
        return locationData.isTrackingEnabled ? "location.fill" : "location.slash"
    }

    private var statusColor: Color {
        if locationData.isManualCheckInOpen { return .green }
        return locationData.isTrackingEnabled ? .green : .gray
    }

    private func refreshData() {
        if let data = SharedLocationData.load() {
            locationData = data
        }
    }
}

@MainActor
final class WatchManualVisitCommandSender: NSObject, ObservableObject {
    @Published var statusMessage: String?
    @Published var isSending = false
    @Published var queuedCommandCount = 0
    @Published var lastResponseSucceeded: Bool?

    func activate() {
        guard WCSession.isSupported() else {
            statusMessage = "Watch commands are unavailable."
            lastResponseSucceeded = false
            return
        }

        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState == .notActivated {
            session.activate()
        }
        updateQueuedCommandCount()
    }

    func send(_ action: WatchManualVisitCommandAction) {
        activate()
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        let command = WatchManualVisitCommand(action: action)
        let payload = command.propertyListPayload
        guard !payload.isEmpty else {
            statusMessage = "Could not prepare command."
            lastResponseSucceeded = false
            return
        }

        isSending = true
        lastResponseSucceeded = nil
        session.transferUserInfo(payload)
        updateQueuedCommandCount()

        guard session.isReachable else {
            isSending = false
            statusMessage = "Queued for iPhone."
            return
        }

        session.sendMessage(payload) { [weak self] reply in
            Task { @MainActor in
                self?.handleReply(reply)
            }
        } errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.isSending = false
                self?.statusMessage = "Queued for iPhone."
                self?.lastResponseSucceeded = nil
                self?.updateQueuedCommandCount()
            }
        }
    }

    private func handleReply(_ reply: [String: Any]) {
        isSending = false
        if let response = WatchManualVisitCommandResponse.decode(from: reply) {
            statusMessage = response.message
            lastResponseSucceeded = response.success
        } else {
            statusMessage = "Queued for iPhone."
            lastResponseSucceeded = nil
        }
        updateQueuedCommandCount()
    }

    private func handleSharedData(_ propertyList: [String: Any]) {
        guard let sharedData = SharedLocationData.decode(from: propertyList) else { return }
        sharedData.save()
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .sharedLocationDataDidUpdate, object: nil)
    }

    private func handleCommandResponse(_ propertyList: [String: Any]) {
        guard let response = WatchManualVisitCommandResponse.decode(from: propertyList) else { return }
        isSending = false
        statusMessage = response.message
        lastResponseSucceeded = response.success
        updateQueuedCommandCount()
    }

    private func updateQueuedCommandCount() {
        guard WCSession.isSupported() else {
            queuedCommandCount = 0
            return
        }
        queuedCommandCount = WCSession.default.outstandingUserInfoTransfers.count
    }
}

extension WatchManualVisitCommandSender: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.updateQueuedCommandCount()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateQueuedCommandCount()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.handleSharedData(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            if SharedLocationData.decode(from: userInfo) != nil {
                self.handleSharedData(userInfo)
            } else {
                self.handleCommandResponse(userInfo)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        Task { @MainActor in
            self.updateQueuedCommandCount()
            if error != nil {
                self.statusMessage = "Could not queue command."
                self.lastResponseSucceeded = false
            }
        }
    }
}

extension Notification.Name {
    static let sharedLocationDataDidUpdate = Notification.Name("sharedLocationDataDidUpdate")
}

#Preview {
    ContentView()
}
