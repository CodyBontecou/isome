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
            // Stop tracking
            NotificationCenter.default.post(name: .stopTracking, object: nil)
            // Backward compatibility for any still-listening legacy observers.
            NotificationCenter.default.post(name: .stopContinuousTracking, object: nil)
        default:
            break
        }
    }
}

struct ActivityStartPromptContext: Identifiable {
    static let notificationIdentifierPrefix = "activityPrompt-"

    private static let typeKey = "promptType"
    private static let idKey = "promptID"
    private static let reasonKey = "promptReason"
    private static let activityTypeKey = "promptActivityType"
    private static let detectedAtKey = "promptDetectedAt"
    private static let typeValue = "movementStartPrompt"

    let id: String
    let reason: String
    let activityType: String
    let detectedAt: Date

    init(id: String = UUID().uuidString, reason: String, activityType: String, detectedAt: Date = Date()) {
        self.id = id
        self.reason = reason
        self.activityType = activityType
        self.detectedAt = detectedAt
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard Self.isActivityPrompt(userInfo) else { return nil }

        let id = userInfo[Self.idKey] as? String ?? UUID().uuidString
        let reason = userInfo[Self.reasonKey] as? String ?? "movement detected"
        let activityType = userInfo[Self.activityTypeKey] as? String ?? "movement"

        let detectedAt: Date
        if let interval = userInfo[Self.detectedAtKey] as? TimeInterval {
            detectedAt = Date(timeIntervalSince1970: interval)
        } else if let number = userInfo[Self.detectedAtKey] as? NSNumber {
            detectedAt = Date(timeIntervalSince1970: number.doubleValue)
        } else {
            detectedAt = Date()
        }

        self.init(id: id, reason: reason, activityType: activityType, detectedAt: detectedAt)
    }

    var userInfo: [String: Any] {
        [
            Self.typeKey: Self.typeValue,
            Self.idKey: id,
            Self.reasonKey: reason,
            Self.activityTypeKey: activityType,
            Self.detectedAtKey: detectedAt.timeIntervalSince1970
        ]
    }

    static func isActivityPrompt(_ userInfo: [AnyHashable: Any]) -> Bool {
        (userInfo[typeKey] as? String) == typeValue
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let stopTracking = Notification.Name("stopTracking")

    /// Legacy notification name kept so old posting paths continue to work during transition.
    static let stopContinuousTracking = Notification.Name("stopContinuousTracking")

    static let activityStartPromptRequested = Notification.Name("activityStartPromptRequested")
}
