import UIKit
import CoreLocation

class AppDelegate: NSObject, UIApplicationDelegate {
    // Shared location manager instance for background launches
    static var sharedLocationManager: LocationManager?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Check if app was launched due to a location event
        if let locationKey = launchOptions?[.location] as? Bool, locationKey {
            // App was launched in background due to location event
            // The LocationManager will be initialized and will receive the pending events
            print("App launched from location event")
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
}
