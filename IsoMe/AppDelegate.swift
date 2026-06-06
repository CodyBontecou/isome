import UIKit
import CoreLocation
import UserNotifications
import ExportAutomationKit
import SwiftData
import WatchConnectivity

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Shared location manager instance for background launches
    static var sharedLocationManager: LocationManager?
    private var watchCommandModelContainer: ModelContainer?
    private var fallbackWatchCommandModelContainer: ModelContainer?
    private let processedWatchCommandIDsKey = "processedWatchManualVisitCommandIDs"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        activateWatchConnectivity()

        // Install crash handler to capture crash info for debugging
        NSSetUncaughtExceptionHandler { exception in
            let info = """
            CRASH: \(exception.name.rawValue)
            REASON: \(exception.reason ?? "unknown")
            STACK: \(exception.callStackSymbols.joined(separator: "\n"))
            """
            UserDefaults.standard.set(info, forKey: "lastCrashLog")
            UserDefaults.standard.synchronize()
        }

        UNUserNotificationCenter.current().delegate = self

        // Register the daily-export background task before applicationDidFinishLaunching returns.
        DailyExportScheduler.registerBackgroundTask()

        // Check if app was launched due to a location event
        if let locationKey = launchOptions?[.location] as? Bool, locationKey {
            // App was launched in background due to location event
            // The LocationManager will be initialized and will receive the pending events
            print("App launched from location event")
        }

        return true
    }

    @MainActor
    func configureWatchCommands(modelContainer: ModelContainer) {
        watchCommandModelContainer = modelContainer
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Ensure location tracking continues in background
        print("App entered background - location tracking continues")
    }

    // MARK: - Remote notifications (server-side scheduled exports)

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistrationManager.shared.submitDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard userInfo["type"] as? String == RemoteScheduleWorkerContract.scheduledExportPushType else {
            completionHandler(.noData)
            return
        }

        let fireDate = scheduledExportFireDate(from: userInfo)
        Task { @MainActor in
            let outcome = await DailyExportScheduler.shared.runFromServerNotification(fireDate: fireDate)
            completionHandler(outcome.completedExport ? .newData : .noData)
        }
    }

    private func scheduledExportFireDate(from userInfo: [AnyHashable: Any]) -> Date? {
        let stringKeys = ["fireAt", "fire_at", "scheduledFireDate", "scheduled_fire_date"]
        let formatter = ISO8601DateFormatter()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for key in stringKeys {
            guard let value = userInfo[key] as? String else { continue }
            if let date = fractionalFormatter.date(from: value) ?? formatter.date(from: value) {
                return date
            }
        }

        for key in stringKeys {
            if let value = userInfo[key] as? TimeInterval {
                return Date(timeIntervalSince1970: value)
            }
            if let value = userInfo[key] as? NSNumber {
                return Date(timeIntervalSince1970: value.doubleValue)
            }
        }

        return nil
    }

    // MARK: - Local notification taps

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        if DailyExportNotificationPayload.isDailyExportNotification(
            identifier: request.identifier,
            userInfo: request.content.userInfo
        ) {
            Task { @MainActor in
                await DailyExportScheduler.shared.runFromNotificationTap(userInfo: request.content.userInfo)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save any pending data before termination
        print("App will terminate - saving state")
    }

    private func activateWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    @MainActor
    private func processWatchManualVisitCommand(_ command: WatchManualVisitCommand) async -> WatchManualVisitCommandResponse {
        if hasProcessedWatchCommand(id: command.id) {
            return WatchManualVisitCommandResponse(
                commandID: command.id,
                success: true,
                message: "Command already handled."
            )
        }

        do {
            let container = try watchCommandContainer()
            let context = container.mainContext
            let manager = LocationManager.shared ?? LocationManager()
            manager.setModelContext(context)

            let viewModel = LocationViewModel(
                modelContext: context,
                locationManager: manager
            )

            switch command.action {
            case .checkIn:
                if let openVisit = try openManualVisit(in: context) {
                    markWatchCommandProcessed(id: command.id)
                    manager.syncDataToWatch()
                    return WatchManualVisitCommandResponse(
                        commandID: command.id,
                        success: true,
                        message: "Already checked in at \(openVisit.displayName)."
                    )
                }

                guard manager.hasLocationPermission else {
                    manager.requestWhenInUseAuthorization()
                    return WatchManualVisitCommandResponse(
                        commandID: command.id,
                        success: false,
                        message: "Open iso.me on iPhone to allow location access."
                    )
                }

                let visit = try await viewModel.createManualVisitAtCurrentLocation(
                    locationName: normalizedWatchCommandText(command.placeName)
                )
                markWatchCommandProcessed(id: command.id)
                manager.syncDataToWatch()
                return WatchManualVisitCommandResponse(
                    commandID: command.id,
                    success: true,
                    message: "Checked in at \(visit.displayName)."
                )

            case .checkOut:
                guard let visit = try openManualVisit(in: context) else {
                    return WatchManualVisitCommandResponse(
                        commandID: command.id,
                        success: false,
                        message: "There is no open manual check-in."
                    )
                }

                try viewModel.checkoutVisit(visit)
                markWatchCommandProcessed(id: command.id)
                manager.syncDataToWatch()
                return WatchManualVisitCommandResponse(
                    commandID: command.id,
                    success: true,
                    message: "Checked out of \(visit.displayName)."
                )
            }
        } catch VisitMutationError.noCurrentLocation {
            return WatchManualVisitCommandResponse(
                commandID: command.id,
                success: false,
                message: "Current location is unavailable on iPhone."
            )
        } catch VisitMutationError.overlappingManualVisit {
            markWatchCommandProcessed(id: command.id)
            return WatchManualVisitCommandResponse(
                commandID: command.id,
                success: true,
                message: "A manual check-in is already open."
            )
        } catch {
            return WatchManualVisitCommandResponse(
                commandID: command.id,
                success: false,
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    func processWatchManualVisitCommandForTesting(
        _ command: WatchManualVisitCommand,
        modelContainer: ModelContainer
    ) async -> WatchManualVisitCommandResponse {
        let previousContainer = watchCommandModelContainer
        watchCommandModelContainer = modelContainer
        defer { watchCommandModelContainer = previousContainer }
        return await processWatchManualVisitCommand(command)
    }

    @MainActor
    private func watchCommandContainer() throws -> ModelContainer {
        if let watchCommandModelContainer {
            return watchCommandModelContainer
        }

        if let fallbackWatchCommandModelContainer {
            return fallbackWatchCommandModelContainer
        }

        let schema = Schema([Visit.self, LocationPoint.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        fallbackWatchCommandModelContainer = container
        return container
    }

    @MainActor
    private func openManualVisit(in context: ModelContext) throws -> Visit? {
        let descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate<Visit> { visit in
                visit.departedAt == nil
            },
            sortBy: [SortDescriptor(\.arrivedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first { $0.source == .manual }
    }

    private func normalizedWatchCommandText(_ text: String?) -> String? {
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func hasProcessedWatchCommand(id: UUID) -> Bool {
        processedWatchCommandIDs().contains(id.uuidString)
    }

    private func markWatchCommandProcessed(id: UUID) {
        var ids = processedWatchCommandIDs()
        ids.insert(id.uuidString)
        if ids.count > 200 {
            ids = Set(ids.sorted().suffix(200))
        }
        UserDefaults.standard.set(Array(ids), forKey: processedWatchCommandIDsKey)
    }

    private func processedWatchCommandIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: processedWatchCommandIDsKey) ?? [])
    }

    private func transferWatchCommandResponse(_ response: WatchManualVisitCommandResponse) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(response.propertyListPayload)
    }
}

extension AppDelegate: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = WatchManualVisitCommand.decode(from: message) else {
            replyHandler([:])
            return
        }

        Task { @MainActor in
            let response = await processWatchManualVisitCommand(command)
            replyHandler(response.propertyListPayload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let command = WatchManualVisitCommand.decode(from: userInfo) else { return }

        Task { @MainActor in
            let response = await processWatchManualVisitCommand(command)
            transferWatchCommandResponse(response)
        }
    }
}
