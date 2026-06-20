import SwiftUI

struct ContentView: View {
    @StateObject private var tracker = WatchLocationTracker()

    private var locationData: SharedLocationData {
        tracker.locationData
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                trackingStatusView

                permissionView

                Button {
                    tracker.toggleTracking()
                } label: {
                    Label(locationData.isTrackingEnabled ? "Stop" : "Start", systemImage: locationData.isTrackingEnabled ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(locationData.isTrackingEnabled ? .red : .green)
                .disabled(!tracker.canUseLocation && !tracker.needsLocationPermission)

                Divider()

                statsView

                if let locationName = locationData.currentLocationName {
                    Divider()
                    currentLocationView(locationName)
                }

                if let error = tracker.lastErrorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if locationData.todayPointsCount > 0 {
                    Button(role: .destructive) {
                        tracker.resetToday()
                    } label: {
                        Text("Reset Today")
                    }
                    .font(.caption)
                }
            }
            .padding()
        }
        .onAppear {
            tracker.refresh()
        }
    }

    private var trackingStatusView: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.largeTitle)
                .foregroundStyle(statusColor)

            Text(locationData.trackingStatus)
                .font(.headline)

            Text("Apple Watch")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if locationData.isTrackingEnabled,
               let remaining = locationData.formattedRemainingTime {
                Text("\(remaining) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var permissionView: some View {
        if let message = tracker.authorizationMessage {
            VStack(spacing: 6) {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if tracker.needsLocationPermission {
                    Button("Enable Location") {
                        tracker.requestLocationPermission()
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var statsView: some View {
        VStack(spacing: 12) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                statItem(value: "\(locationData.todayVisitsCount)", label: "Visits", icon: "mappin.circle")
                statItem(value: locationData.formattedDistance, label: "Distance", icon: "figure.walk")
            }

            statItem(value: "\(locationData.todayPointsCount)", label: "Points", icon: "location.fill")
        }
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func currentLocationView(_ name: String) -> some View {
        VStack(spacing: 4) {
            Text("Current Location")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.subheadline)
                .multilineTextAlignment(.center)

            if let update = locationData.lastUpdateTime {
                Text(update, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        locationData.isTrackingEnabled ? "location.fill" : "location.slash"
    }

    private var statusColor: Color {
        locationData.isTrackingEnabled ? .green : .gray
    }
}

#Preview {
    ContentView()
}
