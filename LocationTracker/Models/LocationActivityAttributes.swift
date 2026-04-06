import ActivityKit
import Foundation

/// Shared attributes for the Location Tracking Live Activity
struct LocationActivityAttributes: ActivityAttributes {
    
    /// Static data that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Current tracking mode
        var trackingMode: TrackingMode
        /// Last known location name (e.g., "Home", "123 Main St")
        var locationName: String?
        /// Number of locations recorded this session
        var locationsRecorded: Int
        /// Distance traveled in meters
        var distanceTraveled: Double
        /// Time remaining for auto-off (nil if "Never")
        var remainingSeconds: Int?
        /// Last update timestamp
        var lastUpdate: Date
        
        enum TrackingMode: String, Codable, Hashable {
            case visits = "Visits"
            case continuous = "Continuous"
        }
    }
    
    /// When tracking started
    var startTime: Date
}
