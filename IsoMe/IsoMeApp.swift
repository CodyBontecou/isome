import SwiftUI
import SwiftData
import StoreKit

@main
struct IsoMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var sessionStart: Date?
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false
    @AppStorage("cumulativeUsageSeconds") private var cumulativeUsageSeconds: Double = 0

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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            #if DEBUG
            MainActor.assumeIsolated {
                MockDataSeeder.seedIfNeeded(modelContext: container.mainContext)
            }
            #endif
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
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                sessionStart = Date()
                requestReviewIfEligible()
                NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
            case .inactive:
                break
            case .background:
                if let start = sessionStart {
                    cumulativeUsageSeconds += Date().timeIntervalSince(start)
                    sessionStart = nil
                }
                NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
            @unknown default:
                break
            }
        }
    }
    
    private func requestReviewIfEligible() {
        guard !hasRequestedReview, cumulativeUsageSeconds >= 1800 else { return }
        hasRequestedReview = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
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

// MARK: - Notification Names

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let stopTracking = Notification.Name("stopTracking")
}
