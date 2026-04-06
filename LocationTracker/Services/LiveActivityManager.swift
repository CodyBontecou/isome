import ActivityKit
import Foundation
import CoreLocation

/// Manages the Live Activity for location tracking
@MainActor
final class LiveActivityManager: ObservableObject {
    
    static let shared = LiveActivityManager()
    
    @Published private(set) var isActivityActive = false
    
    private var currentActivity: Activity<LocationActivityAttributes>?
    private var startTime: Date?
    private var locationsRecorded: Int = 0
    private var totalDistance: Double = 0
    private var lastLocation: CLLocation?
    
    private init() {}
    
    // MARK: - Public API
    
    /// Check if Live Activities are supported and enabled
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    /// Start a new Live Activity for location tracking
    func startActivity(mode: LocationActivityAttributes.ContentState.TrackingMode, autoOffSeconds: Int?) {
        print("🟡 LiveActivityManager.startActivity called")
        print("   areActivitiesEnabled: \(areActivitiesEnabled)")
        print("   Existing activities count: \(Activity<LocationActivityAttributes>.activities.count)")
        
        guard areActivitiesEnabled else {
            print("❌ Live Activities are not enabled in device Settings")
            print("   Go to Settings > Location Tracker > Live Activities")
            return
        }
        
        // End any existing activities first
        Task {
            await endAllActivities()
            await startActivityInternal(mode: mode, autoOffSeconds: autoOffSeconds)
        }
    }
    
    private func startActivityInternal(mode: LocationActivityAttributes.ContentState.TrackingMode, autoOffSeconds: Int?) async {
        startTime = Date()
        locationsRecorded = 0
        totalDistance = 0
        lastLocation = nil
        
        let attributes = LocationActivityAttributes(startTime: startTime!)
        let initialState = LocationActivityAttributes.ContentState(
            trackingMode: mode,
            locationName: nil,
            locationsRecorded: 0,
            distanceTraveled: 0,
            remainingSeconds: autoOffSeconds,
            lastUpdate: Date()
        )
        
        print("🟢 Requesting Live Activity...")
        print("   mode: \(mode)")
        print("   autoOffSeconds: \(String(describing: autoOffSeconds))")
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            isActivityActive = true
            print("✅ Started Live Activity: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }
    
    /// Update the Live Activity with new location data
    func updateActivity(
        location: CLLocation?,
        locationName: String? = nil,
        remainingSeconds: Int? = nil,
        mode: LocationActivityAttributes.ContentState.TrackingMode
    ) {
        guard let activity = currentActivity else { return }
        
        // Update distance if we have a new location
        if let newLocation = location {
            if let last = lastLocation {
                totalDistance += newLocation.distance(from: last)
            }
            lastLocation = newLocation
            locationsRecorded += 1
        }
        
        let updatedState = LocationActivityAttributes.ContentState(
            trackingMode: mode,
            locationName: locationName,
            locationsRecorded: locationsRecorded,
            distanceTraveled: totalDistance,
            remainingSeconds: remainingSeconds,
            lastUpdate: Date()
        )
        
        Task {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
        }
    }
    
    /// End the current Live Activity
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = LocationActivityAttributes.ContentState(
            trackingMode: .visits,
            locationName: "Tracking Stopped",
            locationsRecorded: locationsRecorded,
            distanceTraveled: totalDistance,
            remainingSeconds: nil,
            lastUpdate: Date()
        )
        
        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        currentActivity = nil
        isActivityActive = false
        startTime = nil
        print("Ended Live Activity")
    }
    
    /// End all Live Activities (useful for cleanup)
    func endAllActivities() async {
        for activity in Activity<LocationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        isActivityActive = false
    }
}
