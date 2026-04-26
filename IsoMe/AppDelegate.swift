import UIKit
import CoreLocation
import UserNotifications
import GripeSDK

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    // Shared location manager instance for background launches
    static var sharedLocationManager: LocationManager?
    static var pendingActivityPromptUserInfo: [AnyHashable: Any]?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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

        let gripeAPIKey = (Bundle.main.object(forInfoDictionaryKey: "GripeAPIKey") as? String) ?? ""
        Gripe.start(
            apiKey: gripeAPIKey,
            endpoint: URL(string: "https://gripe.isolated.tech/v1/reports")!,
            dryRun: false,
            repository: "CodyBontecou/ios-location-tracker"
        )

        // Check if app was launched due to a location event
        if let locationKey = launchOptions?[.location] as? Bool, locationKey {
            // App was launched in background due to location event
            // The LocationManager will be initialized and will receive the pending events
            print("App launched from location event")
        }

        // Re-register HealthKit workout observer for background delivery
        // (must be set up on every launch for background delivery to work)
        if UserDefaults.standard.bool(forKey: "autoStartOnWorkout") {
            HealthKitWorkoutObserver.shared.startObserving()
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Ensure location tracking continues in background
        print("App entered background - location tracking continues")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save any pending data before termination
        print("App will terminate - saving state")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard ActivityStartPromptContext.isActivityPrompt(userInfo),
              let prompt = ActivityStartPromptContext(userInfo: userInfo) else {
            completionHandler()
            return
        }

        AppDelegate.pendingActivityPromptUserInfo = prompt.userInfo
        NotificationCenter.default.post(name: .activityStartPromptRequested, object: nil, userInfo: prompt.userInfo)

        Task { @MainActor in
            LogManager.shared.info("[Movement] Notification tapped: \(prompt.reason).")
        }

        completionHandler()
    }
}
