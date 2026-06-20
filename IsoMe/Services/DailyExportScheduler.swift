import Foundation
import BackgroundTasks
import SwiftData
import ExportAutomationKit

/// Schedules and runs a once-per-day automatic export to the user's configured folder.
///
/// Reliability: iOS does not guarantee `BGAppRefreshTask` fires at the requested time.
/// The scheduler layers several best-effort triggers:
/// - local BGAppRefresh;
/// - a server-side APNs silent push at the chosen minute;
/// - a local visible fallback notification shortly after the chosen minute;
/// - foreground catch-up when the app is opened.
///
/// Tapping the fallback notification retries the exact scheduled occurrence, but
/// only if `lastRun` does not already cover that fire date.
@MainActor
final class DailyExportScheduler: ObservableObject {
    enum RunOutcome: Equatable {
        case exported
        case skippedDisabled
        case skippedNotDue
        case skippedAlreadyCompleted
        case failed(String)

        var completedExport: Bool {
            if case .exported = self { return true }
            return false
        }
    }

    static let shared = DailyExportScheduler()

    static let bgTaskIdentifier = "com.bontecou.isome.dailyexport"

    private let defaults: UserDefaults
    private let notificationScheduler: DailyExportNotificationScheduling
    private let enabledKey = "dailyExport.enabled"
    private let hourKey = "dailyExport.hour"
    private let minuteKey = "dailyExport.minute"
    private let formatKey = "dailyExport.format"
    private let dataKindKey = "dailyExport.dataKind"
    private let lastRunKey = "dailyExport.lastRunAt"
    private let lastErrorKey = "dailyExport.lastError"
    private let pendingNotificationIdentifierKey = "dailyExport.pendingNotificationIdentifier"
    private let remoteScheduleHasSyncedKey = "dailyExport.remoteScheduleHasSynced"
    private var requestNotificationPermissionOnNextSchedule = false

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
            let shouldRequestNotificationPermission = requestNotificationPermissionOnNextSchedule && isEnabled
            requestNotificationPermissionOnNextSchedule = false
            scheduleNextBackgroundRun(requestNotificationPermission: shouldRequestNotificationPermission)
        }
    }

    @Published var hour: Int {
        didSet {
            defaults.set(hour, forKey: hourKey)
            scheduleNextBackgroundRun()
        }
    }

    @Published var minute: Int {
        didSet {
            defaults.set(minute, forKey: minuteKey)
            scheduleNextBackgroundRun()
        }
    }

    @Published var format: ExportFormat {
        didSet { defaults.set(Self.rawFormat(format), forKey: formatKey) }
    }

    @Published var dataKind: ExportOptions.DataKind {
        didSet { defaults.set(dataKind.rawValue, forKey: dataKindKey) }
    }

    @Published private(set) var lastRun: Date?
    @Published private(set) var lastError: String?

    private weak var modelContainer: ModelContainer?

    private init(
        defaults: UserDefaults = .standard,
        notificationScheduler: DailyExportNotificationScheduling = UserNotificationDailyExportScheduler()
    ) {
        self.defaults = defaults
        self.notificationScheduler = notificationScheduler
        self.isEnabled = defaults.bool(forKey: enabledKey)
        self.hour = defaults.object(forKey: hourKey) as? Int ?? 21
        self.minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        self.format = Self.formatFromRaw(defaults.string(forKey: formatKey))
        self.dataKind = ExportOptions.DataKind(rawValue: defaults.string(forKey: dataKindKey) ?? "")
            ?? .all
        self.lastRun = defaults.object(forKey: lastRunKey) as? Date
        self.lastError = defaults.string(forKey: lastErrorKey)
    }

    // MARK: - Wiring

    func attach(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Called once during app launch (before applicationDidFinishLaunching returns).
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await DailyExportScheduler.shared.handleBackgroundTask(task as? BGAppRefreshTask)
            }
        }
    }

    // MARK: - Scheduling

    /// Enable or disable daily exports from the user-facing setup control.
    /// The notification permission prompt is only allowed on this explicit setup path.
    func setEnabledFromUserSetup(_ enabled: Bool) {
        requestNotificationPermissionOnNextSchedule = enabled
        isEnabled = enabled
    }

    /// Submit a `BGAppRefreshTaskRequest` for the next scheduled time and mirror
    /// the same schedule to the APNs worker.
    func scheduleNextBackgroundRun(
        cancelPendingFallback: Bool = true,
        requestNotificationPermission: Bool = false
    ) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskIdentifier)

        if cancelPendingFallback {
            cancelStoredFallbackNotification()
        }

        guard isEnabled else {
            if defaults.bool(forKey: remoteScheduleHasSyncedKey) {
                PushRegistrationManager.shared.syncSchedule(automationSchedule)
            }
            return
        }

        PushRegistrationManager.shared.syncSchedule(automationSchedule)
        defaults.set(true, forKey: remoteScheduleHasSyncedKey)

        let nextRunDate = nextScheduledTime(after: Date())
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = nextRunDate
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("DailyExportScheduler: failed to submit BG task: \(error)")
        }

        if requestNotificationPermission {
            Task { @MainActor in
                await PushRegistrationManager.shared.registerForRemoteNotificationsIfNeeded(
                    requestAuthorizationIfNeeded: true
                )
                guard isEnabled else { return }
                schedulePendingExportFallbackNotification(for: nextRunDate)
            }
        } else {
            schedulePendingExportFallbackNotification(for: nextRunDate)
            Task { await PushRegistrationManager.shared.registerForRemoteNotificationsIfNeeded() }
        }
    }

    private func handleBackgroundTask(_ task: BGAppRefreshTask?) async {
        let outcome = await runIfDue(triggeredByScheduledWake: true)
        if isEnabled {
            switch outcome {
            case .exported, .failed:
                break
            case .skippedDisabled, .skippedNotDue, .skippedAlreadyCompleted:
                scheduleNextBackgroundRun()
            }
        }
        task?.setTaskCompleted(success: outcome.completedExport)
    }

    // MARK: - Foreground, notification, and server-triggered runs

    /// Run the daily export if today's scheduled time has passed and we haven't run since.
    @discardableResult
    func runIfDue(triggeredByScheduledWake: Bool = false) async -> RunOutcome {
        guard isEnabled else { return .skippedDisabled }
        let now = Date()
        guard let fireDate = latestScheduledOccurrence(at: now), isDue(for: fireDate, at: now) else {
            return .skippedNotDue
        }
        return await runScheduledExport(fireDate: fireDate, source: triggeredByScheduledWake ? "scheduled wake" : "catch-up")
    }

    /// Run the export immediately, regardless of schedule. Used for "Run Now" UI button.
    @discardableResult
    func runNow() async -> RunOutcome {
        let outcome = await runExport(now: Date(), scheduledFireDate: nil)
        if outcome.completedExport, isEnabled {
            scheduleNextBackgroundRun()
        }
        return outcome
    }

    /// Called by AppDelegate when the server-side APNs worker sends a silent
    /// `scheduled-export` push. The APNs payload may include the exact fire date;
    /// if it does not, use the latest local scheduled occurrence.
    @discardableResult
    func runFromServerNotification(fireDate: Date?) async -> RunOutcome {
        guard isEnabled else { return .skippedDisabled }
        let resolvedFireDate = fireDate ?? latestScheduledOccurrence(at: Date()) ?? Date()
        return await runScheduledExport(fireDate: resolvedFireDate, source: "silent push")
    }

    /// Called when the user taps the visible fallback notification.
    @discardableResult
    func runFromNotificationTap(userInfo: [AnyHashable: Any]) async -> RunOutcome {
        guard isEnabled else { return .skippedDisabled }
        let fireDate = DailyExportNotificationPayload.fireDate(from: userInfo)
            ?? latestScheduledOccurrence(at: Date())
            ?? Date()
        return await runScheduledExport(fireDate: fireDate, source: "notification tap")
    }

    @discardableResult
    private func runScheduledExport(fireDate: Date, source: String) async -> RunOutcome {
        guard isEnabled else { return .skippedDisabled }

        if hasCompletedScheduledOccurrence(fireDate) {
            notificationScheduler.cancelFallbackNotification(fireDate: fireDate)
            return .skippedAlreadyCompleted
        }

        notificationScheduler.cancelFallbackNotification(fireDate: fireDate)
        let outcome = await runExport(now: Date(), scheduledFireDate: fireDate)

        switch outcome {
        case .exported:
            print("DailyExportScheduler: completed scheduled export from \(source)")
            scheduleNextBackgroundRun()
        case .failed(let message):
            await sendImmediateRetryNotification(fireDate: fireDate, reason: message)
            scheduleNextBackgroundRun(cancelPendingFallback: false)
        case .skippedDisabled, .skippedNotDue, .skippedAlreadyCompleted:
            break
        }

        return outcome
    }

    private func runExport(now: Date, scheduledFireDate: Date?) async -> RunOutcome {
        guard let container = await waitForModelContainer() else {
            return fail("No model container attached")
        }
        guard ExportFolderManager.shared.hasDefaultFolder else {
            return fail("No export folder configured")
        }

        let context = container.mainContext
        do {
            let visits = try context.fetch(FetchDescriptor<Visit>())
            let points = try context.fetch(FetchDescriptor<LocationPoint>())
            let recordingSessions = try context.fetch(FetchDescriptor<RecordingSession>())

            var options = ExportOptions()
            options.format = format
            options.dataKind = dataKind

            let pattern = defaults.string(forKey: "exportFilenamePattern") ?? FilenameTemplate.defaultPattern

            let urls = try ExportService.saveToDefaultFolder(
                visits: visits,
                points: points,
                recordingSessions: recordingSessions,
                options: options,
                filenamePattern: pattern
            )

            ExportToastCenter.shared.show(.success(savedURLs: urls))
            recordSuccess(now)
            if let scheduledFireDate {
                notificationScheduler.cancelFallbackNotification(fireDate: scheduledFireDate)
            }
            return .exported
        } catch {
            return fail(error.localizedDescription)
        }
    }

    private func waitForModelContainer() async -> ModelContainer? {
        if let modelContainer { return modelContainer }

        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let modelContainer { return modelContainer }
        }

        return nil
    }

    private func recordSuccess(_ date: Date) {
        lastRun = date
        defaults.set(date, forKey: lastRunKey)
        lastError = nil
        defaults.removeObject(forKey: lastErrorKey)
    }

    private func fail(_ message: String) -> RunOutcome {
        recordError(message)
        ExportToastCenter.shared.show(.failure(message: message))
        return .failed(message)
    }

    private func recordError(_ message: String) {
        lastError = message
        defaults.set(message, forKey: lastErrorKey)
        print("DailyExportScheduler error: \(message)")
    }

    // MARK: - Local fallback notifications

    private func schedulePendingExportFallbackNotification(for fireDate: Date) {
        let identifier = DailyExportNotificationPayload.identifier(for: fireDate)
        defaults.set(identifier, forKey: pendingNotificationIdentifierKey)
        Task {
            do {
                try await notificationScheduler.scheduleFallbackNotification(fireDate: fireDate)
            } catch {
                recordError("Failed to schedule export notification: \(error.localizedDescription)")
            }
        }
    }

    private func sendImmediateRetryNotification(fireDate: Date, reason: String?) async {
        do {
            try await notificationScheduler.sendImmediateRetryNotification(fireDate: fireDate, reason: reason)
            defaults.set(DailyExportNotificationPayload.identifier(for: fireDate), forKey: pendingNotificationIdentifierKey)
        } catch {
            recordError("Failed to send export retry notification: \(error.localizedDescription)")
        }
    }

    private func cancelStoredFallbackNotification() {
        guard let identifier = defaults.string(forKey: pendingNotificationIdentifierKey) else { return }
        notificationScheduler.cancelNotification(identifier: identifier)
        defaults.removeObject(forKey: pendingNotificationIdentifierKey)
    }

    // MARK: - Date math

    func nextScheduledTime(after now: Date) -> Date {
        AutomationScheduleDateMath.calculateNextRunDate(
            schedule: automationSchedule,
            now: now,
            calendar: Calendar.current
        ) ?? now
    }

    private func latestScheduledOccurrence(at now: Date) -> Date? {
        AutomationScheduleDateMath.latestScheduledOccurrenceDate(
            schedule: automationSchedule,
            now: now,
            calendar: Calendar.current
        )
    }

    private func isDue(for fireDate: Date, at now: Date) -> Bool {
        let cal = Calendar.current
        guard cal.isDate(fireDate, inSameDayAs: now) else { return false }
        guard now >= fireDate else { return false }
        return !hasCompletedScheduledOccurrence(fireDate)
    }

    private func hasCompletedScheduledOccurrence(_ fireDate: Date) -> Bool {
        guard let lastRun else { return false }
        return lastRun >= fireDate
    }

    private var automationSchedule: AutomationSchedule {
        AutomationSchedule(
            isEnabled: isEnabled,
            frequency: .daily,
            preferredHour: hour,
            preferredMinute: minute,
            lookbackDays: 1,
            timeZoneIdentifier: TimeZone.current.identifier,
            lastExportDate: lastRun
        )
    }

    // MARK: - Format helpers

    private static func rawFormat(_ format: ExportFormat) -> String {
        switch format {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "markdown"
        case .owntracks: return "owntracks"
        case .overland: return "overland"
        case .gpx: return "gpx"
        case .kml: return "kml"
        case .geojson: return "geojson"
        }
    }

    private static func formatFromRaw(_ raw: String?) -> ExportFormat {
        switch raw {
        case "csv": return .csv
        case "markdown": return .markdown
        case "owntracks": return .owntracks
        case "overland": return .overland
        case "gpx": return .gpx
        case "kml": return .kml
        case "geojson": return .geojson
        default: return .json
        }
    }
}
