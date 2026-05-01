import AppIntents
import SwiftData
import Foundation
import UniformTypeIdentifiers

// MARK: - Helpers

@MainActor
private enum IntentSupport {
    /// A dedicated container for intent-side reads. Uses the same on-disk store as the app.
    static let modelContainer: ModelContainer = {
        let schema = Schema([Visit.self, LocationPoint.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not open IsoMe model container in intent: \(error)")
        }
    }()

    static func makeContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    /// Returns the live LocationManager if one exists, otherwise creates a background-launch
    /// instance wired to the shared store. Lets Start/Stop intents work even when the app's
    /// UI hasn't booted yet.
    static func ensureLocationManager() -> LocationManager {
        if let existing = LocationManager.shared { return existing }
        let manager = LocationManager()
        manager.setModelContext(makeContext())
        return manager
    }

    static var usesMetric: Bool {
        if UserDefaults.standard.object(forKey: "usesMetricDistanceUnits") == nil { return true }
        return UserDefaults.standard.bool(forKey: "usesMetricDistanceUnits")
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    static func todayRange(now: Date = Date()) -> ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        return start...now
    }

    static func yesterdayRange(now: Date = Date()) -> ClosedRange<Date> {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!
        let endOfYesterday = startOfToday.addingTimeInterval(-1)
        return startOfYesterday...endOfYesterday
    }
}

// MARK: - Errors

enum IsoMeIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case noLocationPermission

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noLocationPermission:
            return "IsoMe needs location permission. Open the app to enable it."
        }
    }
}

// MARK: - Tracking Control

struct StartTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Tracking"
    static var description = IntentDescription("Begin recording your route in IsoMe.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = IntentSupport.ensureLocationManager()
        guard manager.hasLocationPermission else {
            throw IsoMeIntentError.noLocationPermission
        }
        manager.startTracking()
        return .result(dialog: "Tracking started.")
    }
}

struct StopTrackingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Tracking"
    static var description = IntentDescription("Stop the current IsoMe tracking session.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if let manager = LocationManager.shared {
            manager.stopTracking()
        } else {
            // No live manager — the app isn't running. Persist the off state so the next
            // launch doesn't auto-resume tracking.
            UserDefaults.standard.set(false, forKey: "isTrackingEnabled")
        }
        return .result(dialog: "Tracking stopped.")
    }
}

// MARK: - Read-Only Stats (backed by SharedLocationData)

struct TodayDistanceIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Distance"
    static var description = IntentDescription("How far you've moved today, according to IsoMe.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Measurement<UnitLength>> {
        let snapshot = SharedLocationData.load() ?? .empty
        let meters = snapshot.todayDistanceMeters
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        let formatted = DistanceFormatter.format(meters: meters, usesMetric: snapshot.prefersMetricDistanceUnits)
        let dialog: IntentDialog = meters <= 0
            ? "You haven't moved yet today."
            : "You've gone \(formatted) today."
        return .result(value: measurement, dialog: dialog)
    }
}

struct TodayTrackingDurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Tracking Duration"
    static var description = IntentDescription("How long the current IsoMe tracking session has been running.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Measurement<UnitDuration>> {
        let snapshot = SharedLocationData.load() ?? .empty
        let seconds: TimeInterval
        let dialog: IntentDialog
        if let start = snapshot.trackingStartTime, snapshot.isTrackingEnabled {
            seconds = Date().timeIntervalSince(start)
            dialog = "You've been tracking for \(IntentSupport.formatDuration(seconds))."
        } else {
            seconds = 0
            dialog = "IsoMe isn't tracking right now."
        }
        return .result(
            value: Measurement(value: seconds, unit: UnitDuration.seconds),
            dialog: dialog
        )
    }
}

struct TodayVisitCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Visits"
    static var description = IntentDescription("Number of visits IsoMe has logged today.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Int> {
        let snapshot = SharedLocationData.load() ?? .empty
        let count = snapshot.todayVisitsCount
        let dialog: IntentDialog
        switch count {
        case 0: dialog = "No visits yet today."
        case 1: dialog = "1 visit today."
        default: dialog = "\(count) visits today."
        }
        return .result(value: count, dialog: dialog)
    }
}

// MARK: - Export

enum IsoMeExportFormat: String, AppEnum {
    case json
    case csv
    case markdown

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Export Format"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .json: "JSON",
        .csv: "CSV",
        .markdown: "Markdown",
    ]

    var format: ExportFormat {
        switch self {
        case .json: return .json
        case .csv: return .csv
        case .markdown: return .markdown
        }
    }

    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        }
    }
}

private struct ExportRunner {
    @MainActor
    static func run(range: ClosedRange<Date>, format: IsoMeExportFormat) throws -> IntentFile {
        let context = IntentSupport.makeContext()

        var visitDescriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { $0.arrivedAt >= range.lowerBound && $0.arrivedAt <= range.upperBound }
        )
        visitDescriptor.sortBy = [SortDescriptor(\.arrivedAt, order: .forward)]

        var pointDescriptor = FetchDescriptor<LocationPoint>(
            predicate: #Predicate { $0.timestamp >= range.lowerBound && $0.timestamp <= range.upperBound }
        )
        pointDescriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]

        let visits = (try? context.fetch(visitDescriptor)) ?? []
        let points = (try? context.fetch(pointDescriptor)) ?? []

        var options = ExportOptions()
        options.dataKind = .all
        options.format = format.format
        options.datePreset = .custom
        options.customStart = range.lowerBound
        options.customEnd = range.upperBound

        let rendered = try ExportService.render(visits: visits, points: points, options: options)
        return IntentFile(data: rendered.data, filename: rendered.fileName, type: format.contentType)
    }
}

struct ExportTodayDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Today's Data"
    static var description = IntentDescription("Export today's IsoMe visits and route as a file.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Format", default: .json)
    var format: IsoMeExportFormat

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let file = try ExportRunner.run(range: IntentSupport.todayRange(), format: format)
        return .result(value: file)
    }
}

struct ExportYesterdayDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Yesterday's Data"
    static var description = IntentDescription("Export yesterday's IsoMe visits and route as a file.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Format", default: .json)
    var format: IsoMeExportFormat

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let file = try ExportRunner.run(range: IntentSupport.yesterdayRange(), format: format)
        return .result(value: file)
    }
}

// MARK: - App Shortcuts (Siri-discoverable phrases)

struct IsoMeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTrackingIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Begin recording in \(.applicationName)",
                "Record route with \(.applicationName)",
            ],
            shortTitle: "Start Tracking",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StopTrackingIntent(),
            phrases: [
                "Stop tracking with \(.applicationName)",
                "Stop \(.applicationName) tracking",
            ],
            shortTitle: "Stop Tracking",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: TodayDistanceIntent(),
            phrases: [
                "How far have I gone with \(.applicationName)",
                "\(.applicationName) distance today",
            ],
            shortTitle: "Today's Distance",
            systemImageName: "ruler"
        )
        AppShortcut(
            intent: TodayTrackingDurationIntent(),
            phrases: [
                "How long have I been tracking with \(.applicationName)",
                "\(.applicationName) tracking duration",
            ],
            shortTitle: "Tracking Duration",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: TodayVisitCountIntent(),
            phrases: [
                "How many visits today in \(.applicationName)",
                "\(.applicationName) visit count",
            ],
            shortTitle: "Today's Visits",
            systemImageName: "mappin.and.ellipse"
        )
        AppShortcut(
            intent: ExportTodayDataIntent(),
            phrases: [
                "Export today's data from \(.applicationName)",
                "Export today's \(.applicationName) tracks",
            ],
            shortTitle: "Export Today",
            systemImageName: "square.and.arrow.up"
        )
        AppShortcut(
            intent: ExportYesterdayDataIntent(),
            phrases: [
                "Export yesterday's data from \(.applicationName)",
                "Export yesterday's \(.applicationName) tracks",
            ],
            shortTitle: "Export Yesterday",
            systemImageName: "square.and.arrow.up"
        )
    }
}
