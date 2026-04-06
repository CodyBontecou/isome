import SwiftUI
import SwiftData
import ActivityKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: LocationViewModel
    @StateObject private var exportFolderManager = ExportFolderManager.shared
    @State private var showingExportOptions = false
    @State private var showingLocationPointsExportOptions = false
    @State private var showingClearConfirmation = false
    @State private var showingFolderPicker = false
    @State private var showingClearFolderConfirmation = false
    @State private var exportSuccessMessage: String?
    @State private var showingExportSuccess = false
    @State private var exportFormat: ExportFormat = .json
    
    // Default tracking settings
    @AppStorage("defaultContinuousTracking") private var defaultContinuousTracking = true
    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true
    @AppStorage("useDefaultExportFolder") private var useDefaultExportFolder = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack {
            Form {
                trackingSection
                continuousTrackingSection
                defaultsSection
                exportFolderSection
                exportSection
                dataSection
                onboardingSection
                aboutSection
            }
            .navigationTitle("Settings")
            .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
                Button("JSON") {
                    exportVisits(format: .json)
                }
                Button("CSV") {
                    exportVisits(format: .csv)
                }
                Button("Markdown") {
                    exportVisits(format: .markdown)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose export format for visits")
            }
            .confirmationDialog("Export Format", isPresented: $showingLocationPointsExportOptions) {
                Button("JSON") {
                    exportLocationPoints(format: .json)
                }
                Button("CSV") {
                    exportLocationPoints(format: .csv)
                }
                Button("Markdown") {
                    exportLocationPoints(format: .markdown)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose export format for location points")
            }
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    viewModel.clearAllData()
                }
            } message: {
                Text("This will permanently delete all visit data and location points. This action cannot be undone.")
            }
            .alert("Remove Default Folder?", isPresented: $showingClearFolderConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    exportFolderManager.clearDefaultFolder()
                }
            } message: {
                Text("Exports will use the share sheet instead of saving directly to a folder.")
            }
            .alert("Export Complete", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = exportSuccessMessage {
                    Text(message)
                }
            }
            .sheet(isPresented: $showingFolderPicker) {
                FolderPicker { url in
                    if let url = url {
                        exportFolderManager.setDefaultFolder(url)
                    }
                }
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

            Picker("Distance Filter", selection: Binding(
                get: { viewModel.locationManager.distanceFilter },
                set: {
                    viewModel.locationManager.distanceFilter = $0
                    UserDefaults.standard.set($0, forKey: "distanceFilter")
                }
            )) {
                Text("5 meters").tag(5.0)
                Text("10 meters").tag(10.0)
                Text("25 meters").tag(25.0)
                Text("50 meters").tag(50.0)
                Text("100 meters").tag(100.0)
                Text("200 meters").tag(200.0)
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
    
    // MARK: - Export Folder Section
    
    private var exportFolderSection: some View {
        Section {
            if let folderName = exportFolderManager.selectedFolderName {
                HStack {
                    Label(folderName, systemImage: "folder.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Text("Change")
                            .font(.subheadline)
                    }
                }
                
                Toggle("Auto-save to folder", isOn: $useDefaultExportFolder)
                
                Button(role: .destructive) {
                    showingClearFolderConfirmation = true
                } label: {
                    Label("Remove Default Folder", systemImage: "folder.badge.minus")
                }
            } else {
                Button {
                    showingFolderPicker = true
                } label: {
                    Label("Select Export Folder", systemImage: "folder.badge.plus")
                }
            }
        } header: {
            Text("Default Export Folder")
        } footer: {
            if exportFolderManager.hasDefaultFolder {
                Text("Exports will be saved directly to this folder when auto-save is enabled.")
            } else {
                Text("Set a default folder to save exports automatically without using the share sheet.")
            }
        }
    }
    
    // MARK: - Export Section

    private var exportSection: some View {
        Section {
            Button {
                showingExportOptions = true
            } label: {
                HStack {
                    Label("Export Visits", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text("\(viewModel.allVisits.count) visits")
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                showingLocationPointsExportOptions = true
            } label: {
                HStack {
                    Label("Export Location Points", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    Spacer()
                    Text("\(viewModel.locationPoints.count) points")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Data Export")
        } footer: {
            if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
                Text("Files will be saved to \(exportFolderManager.selectedFolderName ?? "your folder").")
            } else {
                Text("Export visits or time-series location points as JSON, CSV, or Markdown.")
            }
        }
    }
    
    // MARK: - Export Helpers
    
    private func exportVisits(format: ExportFormat) {
        if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
            do {
                let url = try ExportService.exportToDefaultFolder(visits: viewModel.allVisits, format: format)
                exportSuccessMessage = "Saved to \(url.lastPathComponent)"
                showingExportSuccess = true
            } catch {
                viewModel.exportError = error.localizedDescription
            }
        } else {
            viewModel.exportVisits(format: format)
        }
    }
    
    private func exportLocationPoints(format: ExportFormat) {
        if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
            do {
                let url = try ExportService.exportLocationPointsToDefaultFolder(points: viewModel.locationPoints, format: format)
                exportSuccessMessage = "Saved to \(url.lastPathComponent)"
                showingExportSuccess = true
            } catch {
                viewModel.exportError = error.localizedDescription
            }
        } else {
            viewModel.exportLocationPoints(format: format)
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

    // MARK: - Onboarding Section

    private var onboardingSection: some View {
        Section {
            Button {
                hasCompletedOnboarding = false
            } label: {
                Label("Show Onboarding Again", systemImage: "sparkles")
            }
        } header: {
            Text("Onboarding")
        } footer: {
            Text("Replay the onboarding flow to revisit app tips and permission setup guidance.")
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

// MARK: - Folder Picker

struct FolderPicker: UIViewControllerRepresentable {
    let onFolderSelected: (URL?) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFolderSelected: onFolderSelected)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFolderSelected: (URL?) -> Void
        
        init(onFolderSelected: @escaping (URL?) -> Void) {
            self.onFolderSelected = onFolderSelected
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFolderSelected(urls.first)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFolderSelected(nil)
        }
    }
}
