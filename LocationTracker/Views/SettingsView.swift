import SwiftUI
import SwiftData
import ActivityKit

struct SettingsView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var showingExportOptions = false
    @State private var showingClearConfirmation = false
    @State private var exportFormat: ExportFormat = .json
    
    // Default tracking settings
    @AppStorage("defaultContinuousTracking") private var defaultContinuousTracking = true
    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                trackingSection
                continuousTrackingSection
                defaultsSection
                exportSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
                Button("JSON") {
                    exportFormat = .json
                    viewModel.exportVisits(format: .json)
                }
                Button("CSV") {
                    exportFormat = .csv
                    viewModel.exportVisits(format: .csv)
                }
                Button("Markdown") {
                    exportFormat = .markdown
                    viewModel.exportVisits(format: .markdown)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose export format")
            }
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("This will permanently delete all visit data and location points. This action cannot be undone.")
            }
        }
    }

    // MARK: - Tracking Section

    private var trackingSection: some View {
        Section {
            Toggle("Enable Location Tracking", isOn: Binding(
                get: { viewModel.locationManager.isTrackingEnabled },
                set: { newValue in
                    if newValue {
                        viewModel.startTracking()
                    } else {
                        viewModel.stopTracking()
                    }
                }
            ))

            HStack {
                Text("Permission Status")
                Spacer()
                Text(permissionStatusText)
                    .foregroundStyle(permissionStatusColor)
            }

            if !viewModel.locationManager.hasAlwaysPermission {
                Button("Open Location Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("Location Tracking")
        } footer: {
            Text("Visit monitoring tracks places you visit. Significant location changes provides a trail between visits.")
        }
    }

    private var permissionStatusText: String {
        switch viewModel.locationManager.authorizationStatus {
        case .notDetermined:
            return "Not Set"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedWhenInUse:
            return "When In Use"
        case .authorizedAlways:
            return "Always"
        @unknown default:
            return "Unknown"
        }
    }

    private var permissionStatusColor: Color {
        switch viewModel.locationManager.authorizationStatus {
        case .authorizedAlways:
            return .blue
        case .authorizedWhenInUse:
            return .blue.opacity(0.7)
        case .denied, .restricted:
            return .blue.opacity(0.5)
        default:
            return .secondary
        }
    }

    // MARK: - Continuous Tracking Section

    private var continuousTrackingSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.locationManager.isContinuousTrackingEnabled },
                set: { newValue in
                    if newValue {
                        viewModel.enableContinuousTracking()
                    } else {
                        viewModel.disableContinuousTracking()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continuous Tracking")
                    if viewModel.locationManager.isContinuousTrackingEnabled {
                        Text("Recording high-accuracy location")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            
            // Live Activity Status
            HStack {
                Text("Live Activity")
                Spacer()
                if ActivityAuthorizationInfo().areActivitiesEnabled {
                    if LiveActivityManager.shared.isActivityActive {
                        Text("Active")
                            .foregroundStyle(.green)
                    } else {
                        Text("Ready")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Disabled in Settings")
                        .foregroundStyle(.orange)
                }
            }
            
            if !ActivityAuthorizationInfo().areActivitiesEnabled {
                Button("Enable Live Activities") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
            }
            


            Picker("Auto-off Duration", selection: Binding(
                get: { viewModel.locationManager.continuousTrackingAutoOffHours },
                set: {
                    viewModel.locationManager.continuousTrackingAutoOffHours = $0
                    UserDefaults.standard.set($0, forKey: "continuousTrackingAutoOffHours")
                }
            )) {
                Text("30 minutes").tag(0.5)
                Text("1 hour").tag(1.0)
                Text("2 hours").tag(2.0)
                Text("4 hours").tag(4.0)
                Text("8 hours").tag(8.0)
                Text("Never").tag(0.0)
            }
        } header: {
            Text("High-Accuracy Mode")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "battery.25")
                        .foregroundStyle(.blue)
                    Text("High battery usage")
                        .foregroundStyle(.blue)
                }
                Text("Continuous tracking records your exact path between visits. Use sparingly.")
            }
        }
    }

    // MARK: - Defaults Section
    
    private var defaultsSection: some View {
        Section {
            Toggle("Enable Location Tracking by Default", isOn: $defaultLocationTrackingEnabled)
            
            Toggle("Use Continuous Tracking Mode", isOn: $defaultContinuousTracking)
        } header: {
            Text("Tracking Defaults")
        } footer: {
            Text("These settings control the default behavior when starting tracking from the Track tab.")
        }
    }
    
    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            Button {
                showingExportOptions = true
            } label: {
                HStack {
                    Label("Export All Data", systemImage: "square.and.arrow.up")
                    Spacer()
                    Text("\(viewModel.allVisits.count) visits")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Data Export")
        } footer: {
            Text("Export visits as JSON or CSV to save or share your location history.")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            HStack {
                Text("Total Visits")
                Spacer()
                Text("\(viewModel.allVisits.count)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Location Points")
                Spacer()
                Text("\(viewModel.locationPoints.count)")
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        } header: {
            Text("Data Management")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Data Storage")
                Spacer()
                Text("On-device only")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        } footer: {
            Text("All location data is stored locally on your device and never uploaded to any server.")
        }
    }
}

#Preview {
    SettingsView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}
