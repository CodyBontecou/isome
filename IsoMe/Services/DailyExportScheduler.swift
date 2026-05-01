import Foundation
import BackgroundTasks
import SwiftData

/// Schedules and runs a once-per-day automatic export to the user's configured folder.
///
/// Reliability: iOS does not guarantee `BGAppRefreshTask` fires at the requested time.
/// To stay correct, the scheduler also runs on app foreground if today's run is overdue.
@MainActor
final class DailyExportScheduler: ObservableObject {
    static let shared = DailyExportScheduler()

    static let bgTaskIdentifier = "com.bontecou.isome.dailyexport"

    private let defaults = UserDefaults.standard
    private let enabledKey = "dailyExport.enabled"
    private let hourKey = "dailyExport.hour"
    private let minuteKey = "dailyExport.minute"
    private let formatKey = "dailyExport.format"
    private let dataKindKey = "dailyExport.dataKind"
    private let lastRunKey = "dailyExport.lastRunAt"
    private let lastErrorKey = "dailyExport.lastError"

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
            scheduleNextBackgroundRun()
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

    private init() {
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

    /// Submit a `BGAppRefreshTaskRequest` for the next scheduled time.
    func scheduleNextBackgroundRun() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.bgTaskIdentifier)
        guard isEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = nextScheduledTime(after: Date())
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("DailyExportScheduler: failed to submit BG task: \(error)")
        }
    }

    private func handleBackgroundTask(_ task: BGAppRefreshTask?) async {
        // Always reschedule first so the chain continues regardless of run outcome.
        scheduleNextBackgroundRun()
        await runIfDue()
        task?.setTaskCompleted(success: lastError == nil)
    }

    // MARK: - Foreground catch-up

    /// Run the daily export if today's scheduled time has passed and we haven't run since.
    func runIfDue() async {
        guard isEnabled else { return }
        guard isDue(at: Date()) else { return }
        await runExport(now: Date())
    }

    /// Run the export immediately, regardless of schedule. Used for "Run Now" UI button.
    func runNow() async {
        await runExport(now: Date())
    }

    private func runExport(now: Date) async {
        guard let container = modelContainer else {
            recordError("No model container attached")
            return
        }
        guard ExportFolderManager.shared.hasDefaultFolder else {
            recordError("No export folder configured")
            return
        }

        let context = container.mainContext
        do {
            let visits = try context.fetch(FetchDescriptor<Visit>())
            let points = try context.fetch(FetchDescriptor<LocationPoint>())

            var options = ExportOptions()
            options.format = format
            options.dataKind = dataKind

            let pattern = defaults.string(forKey: "exportFilenamePattern") ?? FilenameTemplate.defaultPattern

            _ = try ExportService.saveToDefaultFolder(
                visits: visits,
                points: points,
                options: options,
                filenamePattern: pattern
            )

            lastRun = now
            defaults.set(now, forKey: lastRunKey)
            lastError = nil
            defaults.removeObject(forKey: lastErrorKey)
        } catch {
            recordError(error.localizedDescription)
        }
    }

    private func recordError(_ message: String) {
        lastError = message
        defaults.set(message, forKey: lastErrorKey)
        print("DailyExportScheduler error: \(message)")
    }

    // MARK: - Date math

    func nextScheduledTime(after now: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        var target = cal.date(from: comps) ?? now
        if target <= now {
            target = cal.date(byAdding: .day, value: 1, to: target) ?? target
        }
        return target
    }

    private func isDue(at now: Date) -> Bool {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard let scheduledToday = cal.date(from: comps) else { return false }
        guard now >= scheduledToday else { return false }
        if let last = lastRun, last >= scheduledToday { return false }
        return true
    }

    // MARK: - Format helpers

    private static func rawFormat(_ format: ExportFormat) -> String {
        switch format {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "markdown"
        }
    }

    private static func formatFromRaw(_ raw: String?) -> ExportFormat {
        switch raw {
        case "csv": return .csv
        case "markdown": return .markdown
        default: return .json
        }
    }
}
