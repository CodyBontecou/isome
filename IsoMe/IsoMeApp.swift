import SwiftUI
import SwiftData
import StoreKit

@main
struct IsoMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var watchSyncReceiver = WatchLocationSyncReceiver()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Visit.self,
            LocationPoint.self,
            RecordingSession.self,
            PhotoMoment.self,
            SavedPlace.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    watchSyncReceiver.configure(modelContainer: sharedModelContainer)
                    DailyExportScheduler.shared.attach(modelContainer: sharedModelContainer)
                    DailyExportScheduler.shared.scheduleNextBackgroundRun()
                    await DailyExportScheduler.shared.runIfDue()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                AppReviewPromptCoordinator.shared.recordAppUse()
                NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
                Task { await DailyExportScheduler.shared.runIfDue() }
            case .inactive:
                break
            case .background:
                NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
                DailyExportScheduler.shared.scheduleNextBackgroundRun()
            @unknown default:
                break
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "isome" else { return }

        switch url.host {
        case "stop":
            NotificationCenter.default.post(name: .stopTracking, object: nil)
        default:
            break
        }
    }
}

