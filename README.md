# iso.me

A privacy-first location tracking app for iOS and watchOS. Automatically records the places you visit throughout the day, captures routes with high-accuracy GPS logging, and keeps all data on-device. No accounts, no cloud sync, no third-party dependencies.

## Features

### Visit Detection
Automatic background detection of places you arrive at and depart from, powered by `CLLocationManager` visit monitoring. Each visit is reverse-geocoded to show a human-readable address and location name.

### Tracking
High-accuracy GPS tracking that records your exact path. Configurable distance filter (5m-200m) and auto-off timer (30 min to never). Tracked points include altitude, speed, and accuracy metadata.

### Movement Prompt Detection
Instead of starting recording immediately, iso.me can detect movement (driving, cycling, running, walking) and send a notification prompt. When enabled:

1. Significant location changes (~500m movement) wake the app in the background
2. CoreMotion is queried for the current activity type
3. If configured movement is detected, a notification asks whether to start recording
4. Tapping the notification opens a confirmation screen with **Start** / **Not now**
5. If a prompted session starts, it can auto-stop when stationary

Configure this in **Settings > Automation > Prompt on Movement**.

### Live Activities
Real-time tracking status on the lock screen and Dynamic Island. Shows current location, distance traveled, points recorded, and remaining auto-off time.

### Export & Import
Export visits and location points as JSON, CSV, or Markdown. Optionally set a default export folder for one-tap saves. Import previously exported data back into the app.

### Watch App
Companion watchOS app showing today's visit count, distance traveled, and tracking status. Syncs with the main app via shared App Groups.

### Widgets
iOS lock screen widget via Live Activities and watchOS complications for quick tracking status.

### iso.me Pro
Tracking is always free. A one-time lifetime purchase unlocks data export.

## Tech Stack

- **Language:** Swift 5
- **UI:** SwiftUI
- **Data:** SwiftData
- **Minimum iOS:** 17.0
- **Minimum watchOS:** 10.0
- **Dependencies:** None (all native Apple frameworks)

### Frameworks Used

| Framework | Purpose |
|-----------|---------|
| CoreLocation | Visit monitoring, GPS tracking, geocoding |
| CoreMotion | Activity detection (driving, walking, cycling) |
| SwiftData | On-device persistence for visits and location points |
| ActivityKit | Live Activities on lock screen and Dynamic Island |
| WidgetKit | Home screen and watch widgets |
| StoreKit 2 | In-app purchase (lifetime unlock) |
| MapKit | Map visualization and route display |
| Combine | Reactive state management |

## Project Structure

```
IsoMe/
  Models/
    Visit.swift                    # Visit data model (coordinates, times, address)
    LocationPoint.swift            # Tracking point model
    LocationActivityAttributes.swift  # Live Activity state
  Services/
    LocationManager.swift          # Core location tracking logic
    ActivityDetectionManager.swift # CoreMotion activity detection
    LiveActivityManager.swift      # Live Activity lifecycle
    GeocodingService.swift         # Reverse geocoding with caching
    StoreManager.swift             # In-app purchase management
    LogManager.swift               # Crash and debug logging
  ViewModels/
    LocationViewModel.swift        # Data coordination between UI and services
  Views/
    ContentView.swift              # Root view with onboarding and tab navigation
    MapView.swift                  # Map with visit pins
    SessionPathMapView.swift       # Route path visualization
    SettingsView.swift             # Preferences, export, import, data management
    VisitDetailView.swift          # Individual visit details
    PaywallView.swift              # Pro upgrade screen
    LogViewerView.swift            # Debug log viewer
  Utilities/
    ExportService.swift            # JSON/CSV/Markdown export
    ImportService.swift            # Data import parsing
    ExportFolderManager.swift      # Default export folder management
    DistanceFormatter.swift        # Metric/imperial formatting
    TEDesign.swift                 # Design tokens and typography
  IsoMeApp.swift                   # App entry point
  AppDelegate.swift                # Background launch handling

IsoMeWidget/                       # iOS widget and Live Activity extension
IsoMeWatch/                        # watchOS companion app
IsoMeWatchWidget/                  # watchOS widget extension
Shared/                            # Shared code (App Group data sync)
```

## Build Targets

| Target | Bundle ID | Platform |
|--------|-----------|----------|
| IsoMe | `com.bontecou.isome` | iOS |
| IsoMeWidgetExtension | `com.bontecou.isome.Widget` | iOS |
| IsoMeWatch | `com.bontecou.isome.watchkitapp` | watchOS |
| IsoMeWatchWidgetExtension | `com.bontecou.isome.watchkitapp.Widget` | watchOS |

## Setup

1. Open `IsoMe.xcodeproj` in Xcode 15+
2. Select the **IsoMe** scheme
3. Set your development team for all four targets
4. Configure the App Group entitlement (`group.com.bontecou.isome`) for your team
5. Build and run on a physical device (location features require real hardware)

### Required Permissions

The app requests the following permissions at runtime:

- **Location (Always)** - Background visit detection and tracking
- **Location (When in Use)** - Foreground location display
- **Motion & Fitness** - Movement detection and start prompts

### Entitlements

- App Groups (`group.com.bontecou.isome`) - Shared data between app, widgets, and watch
- Background Modes: Location updates
- Live Activities support

## URL Scheme

The app registers the `isome://` URL scheme. Currently supports:

- `isome://stop` - Stops tracking (used by Live Activity)
