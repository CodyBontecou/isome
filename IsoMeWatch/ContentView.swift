import SwiftUI

struct ContentView: View {
    @State private var locationData: SharedLocationData = .empty

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tracking Status Header
                trackingStatusView

                Divider()

                // Today's Stats
                statsView

                if let locationName = locationData.currentLocationName {
                    Divider()
                    currentLocationView(locationName)
                }
            }
            .padding()
        }
        .onAppear {
            refreshData()
        }
    }

    private var trackingStatusView: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 36))
                .foregroundStyle(statusColor)

            Text(locationData.trackingStatus)
                .font(.headline)

            if locationData.isTrackingEnabled,
               let remaining = locationData.formattedRemainingTime {
                Text("\(remaining) remaining")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            if locationData.todayPointsCount > 0 {
                statItem(value: "\(locationData.todayPointsCount)", label: "Points", icon: "location.fill")
            }
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
        }
    }

    private var statusIcon: String {
        if locationData.isTrackingEnabled {
            return "location.fill"
        } else {
            return "location.slash"
        }
    }

    private var statusColor: Color {
        if locationData.isTrackingEnabled {
            return .green
        } else {
            return .gray
        }
    }

    private func refreshData() {
        if let data = SharedLocationData.load() {
            locationData = data
        }
    }
}

#Preview {
    ContentView()
}
