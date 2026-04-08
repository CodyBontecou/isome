import SwiftUI
import SwiftData

@main
struct SpottedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Visit.self,
            LocationPoint.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active - refresh data
                NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
            case .inactive:
                break
            case .background:
                // App entered background - ensure data is saved
                NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
            @unknown default:
                break
            }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "spotted" else { return }
        
        switch url.host {
        case "stop":
            // Stop continuous tracking
            NotificationCenter.default.post(name: .stopContinuousTracking, object: nil)
        default:
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let stopContinuousTracking = Notification.Name("stopContinuousTracking")
}
