import SwiftUI
import SwiftData
import ActivityKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: LocationViewModel
    @StateObject private var exportFolderManager = ExportFolderManager.shared
    @ObservedObject private var usageTracker = UsageTracker.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPaywall = false
    @State private var showingExportOptions = false
    @State private var showingLocationPointsExportOptions = false
    @State private var showingClearConfirmation = false
    @State private var showingFolderPicker = false
    @State private var showingClearFolderConfirmation = false
    @State private var exportSuccessMessage: String?
    @State private var showingExportSuccess = false
    @State private var exportFormat: ExportFormat = .json
    @State private var showingImportPicker = false
    @State private var importResultMessage: String?
    @State private var showingImportResult = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false

    @AppStorage("defaultContinuousTracking") private var defaultContinuousTracking = true
    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true
    @AppStorage("useDefaultExportFolder") private var useDefaultExportFolder = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("usesMetricDistanceUnits") private var usesMetricDistanceUnits = true
    @AppStorage("allowNetworkGeocoding") private var allowNetworkGeocoding = true

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        purchaseSection
                        trackingSection
                        continuousTrackingSection
                        defaultsSection
                        unitsSection
                        exportFolderSection
                        exportSection
                        importSection
                        dataSection
                        onboardingSection
                        aboutSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SETTINGS")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(TE.textMuted)
                }
            }
            .confirmationDialog("Export Format", isPresented: $showingExportOptions) {
                Button("JSON") { exportVisits(format: .json) }
                Button("CSV") { exportVisits(format: .csv) }
                Button("Markdown") { exportVisits(format: .markdown) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose export format for visits")
            }
            .confirmationDialog("Export Format", isPresented: $showingLocationPointsExportOptions) {
                Button("JSON") { exportLocationPoints(format: .json) }
                Button("CSV") { exportLocationPoints(format: .csv) }
                Button("Markdown") { exportLocationPoints(format: .markdown) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose export format for location points")
            }
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { viewModel.clearAllData() }
            } message: {
                Text("This will permanently delete all visit data and location points. This action cannot be undone.")
            }
            .alert("Remove Default Folder?", isPresented: $showingClearFolderConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) { exportFolderManager.clearDefaultFolder() }
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
            .alert("Import Complete", isPresented: $showingImportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = importResultMessage {
                    Text(message)
                }
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = importErrorMessage {
                    Text(message)
                }
            }
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json, .commaSeparatedText, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .sheet(isPresented: $showingFolderPicker) {
                FolderPicker { url in
                    if let url = url {
                        exportFolderManager.setDefaultFolder(url)
                    }
                }
            }
            .onChange(of: usesMetricDistanceUnits) { _, _ in
                viewModel.locationManager.refreshDistanceUnitPreference()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeManager: storeManager)
            }
        }
    }

    // MARK: - Purchase Section

    private var purchaseSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "OWNPATH PRO")

            TECard {
                VStack(spacing: 0) {
                    if storeManager.isPurchased {
                        TERow(showDivider: false) {
                            HStack {
                                Circle()
                                    .fill(TE.success)
                                    .frame(width: 6, height: 6)
                                Text("UNLIMITED TRACKING")
                                    .font(TE.mono(.caption, weight: .semibold))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Text("PURCHASED")
                                    .font(TE.mono(.caption2, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.success)
                            }
                        }
                    } else {
                        let totalHours = usageTracker.totalUsageHours
                        let limitHours = UsageTracker.freeUsageLimitSeconds / 3600

                        TERow {
                            HStack {
                                Text("USAGE")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Text("\(totalHours, specifier: "%.1f") / \(limitHours, specifier: "%.0f") HR")
                                    .font(TE.mono(.caption2, weight: .medium))
                                    .foregroundStyle(usageTracker.hasExceededFreeLimit ? TE.danger : TE.textMuted)
                            }
                        }

                        TERow {
                            settingsButton("UNLOCK UNLIMITED", icon: "lock.open.fill") {
                                showingPaywall = true
                            }
                        }

                        TERow(showDivider: false) {
                            settingsButton("RESTORE PURCHASE", icon: "arrow.clockwise") {
                                Task { await storeManager.restorePurchases() }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            if !storeManager.isPurchased {
                TESectionFooter(text: "Free for your first 10 hours. One-time purchase for unlimited use.")
            }
        }
    }

    // MARK: - Tracking Section

    private var trackingSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "LOCATION TRACKING")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        settingsToggle(
                            "TRACKING",
                            isOn: Binding(
                                get: { viewModel.locationManager.isTrackingEnabled },
                                set: { newValue in
                                    if newValue {
                                        if usageTracker.hasExceededFreeLimit && !storeManager.isPurchased {
                                            showingPaywall = true
                                            return
                                        }
                                        viewModel.startTracking()
                                    } else {
                                        viewModel.stopTracking()
                                    }
                                }
                            )
                        )
                    }

                    TERow {
                        HStack {
                            Text("PERMISSION")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Text(permissionStatusText.uppercased())
                                .font(TE.mono(.caption2, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(permissionStatusColor)
                        }
                    }

                    if !viewModel.locationManager.hasAlwaysPermission {
                        TERow {
                            settingsButton("OPEN SETTINGS", icon: "arrow.up.right") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }

                    TERow(showDivider: false) {
                        settingsToggle("LOCATION NAMES", isOn: $allowNetworkGeocoding)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Visit monitoring tracks places you visit. Significant location changes provides a trail between visits. Location names are looked up when available.")
        }
    }

    private var permissionStatusText: String {
        switch viewModel.locationManager.authorizationStatus {
        case .notDetermined: return String(localized: "Not Set")
        case .restricted: return String(localized: "Restricted")
        case .denied: return String(localized: "Denied")
        case .authorizedWhenInUse: return String(localized: "When In Use")
        case .authorizedAlways: return String(localized: "Always")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private var permissionStatusColor: Color {
        switch viewModel.locationManager.authorizationStatus {
        case .authorizedAlways: return TE.accent
        case .authorizedWhenInUse: return TE.accent.opacity(0.7)
        case .denied, .restricted: return TE.danger
        default: return TE.textMuted
        }
    }

    // MARK: - Continuous Tracking Section

    private var continuousTrackingSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "HIGH-ACCURACY MODE")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        settingsToggle(
                            "CONTINUOUS",
                            isOn: Binding(
                                get: { viewModel.locationManager.isContinuousTrackingEnabled },
                                set: { newValue in
                                    if newValue {
                                        if usageTracker.hasExceededFreeLimit && !storeManager.isPurchased {
                                            showingPaywall = true
                                            return
                                        }
                                        viewModel.enableContinuousTracking()
                                    } else {
                                        viewModel.disableContinuousTracking()
                                    }
                                }
                            )
                        )
                    }

                    TERow {
                        HStack {
                            Text("LIVE ACTIVITY")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            if ActivityAuthorizationInfo().areActivitiesEnabled {
                                if LiveActivityManager.shared.isActivityActive {
                                    Text("ACTIVE")
                                        .font(TE.mono(.caption2, weight: .medium))
                                        .tracking(1)
                                        .foregroundStyle(TE.success)
                                } else {
                                    Text("READY")
                                        .font(TE.mono(.caption2, weight: .medium))
                                        .tracking(1)
                                        .foregroundStyle(TE.textMuted)
                                }
                            } else {
                                Text("DISABLED")
                                    .font(TE.mono(.caption2, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.warning)
                            }
                        }
                    }

                    TERow {
                        HStack {
                            Text("AUTO-OFF")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.locationManager.continuousTrackingAutoOffHours },
                                set: {
                                    viewModel.locationManager.continuousTrackingAutoOffHours = $0
                                    UserDefaults.standard.set($0, forKey: "continuousTrackingAutoOffHours")
                                }
                            )) {
                                Text("30m").tag(0.5)
                                Text("1h").tag(1.0)
                                Text("2h").tag(2.0)
                                Text("4h").tag(4.0)
                                Text("8h").tag(8.0)
                                Text("Never").tag(0.0)
                            }
                            .labelsHidden()
                            .tint(TE.accent)
                        }
                    }

                    TERow(showDivider: false) {
                        HStack {
                            Text("DISTANCE FILTER")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.locationManager.distanceFilter },
                                set: {
                                    viewModel.locationManager.distanceFilter = $0
                                    UserDefaults.standard.set($0, forKey: "distanceFilter")
                                }
                            )) {
                                Text("5m").tag(5.0)
                                Text("10m").tag(10.0)
                                Text("25m").tag(25.0)
                                Text("50m").tag(50.0)
                                Text("100m").tag(100.0)
                                Text("200m").tag(200.0)
                            }
                            .labelsHidden()
                            .tint(TE.accent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "High battery usage. Records your exact path between visits.")
        }
    }

    // MARK: - Defaults Section

    private var defaultsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "TRACKING DEFAULTS")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        settingsToggle("LOCATION ON START", isOn: $defaultLocationTrackingEnabled)
                    }

                    TERow(showDivider: false) {
                        settingsToggle("CONTINUOUS MODE", isOn: $defaultContinuousTracking)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Default behavior when starting tracking from the Track tab.")
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "UNITS")

            TECard {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        unitButton("METRIC", isSelected: usesMetricDistanceUnits) {
                            usesMetricDistanceUnits = true
                        }
                        Rectangle()
                            .fill(TE.border)
                            .frame(width: 1)
                        unitButton("US STANDARD", isSelected: !usesMetricDistanceUnits) {
                            usesMetricDistanceUnits = false
                        }
                    }
                    .frame(height: 44)
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Distance values shown throughout the app, widgets, and Live Activity.")
        }
    }

    private func unitButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TE.mono(.caption2, weight: isSelected ? .bold : .medium))
                .tracking(1.5)
                .foregroundStyle(isSelected ? TE.accent : TE.textMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? TE.accent.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export Folder Section

    private var exportFolderSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "EXPORT FOLDER")

            TECard {
                VStack(spacing: 0) {
                    if let folderName = exportFolderManager.selectedFolderName {
                        TERow {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TE.accent)
                                Text(folderName.uppercased())
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(0.5)
                                    .foregroundStyle(TE.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    showingFolderPicker = true
                                } label: {
                                    Text("CHANGE")
                                        .font(TE.mono(.caption2, weight: .semibold))
                                        .tracking(1)
                                        .foregroundStyle(TE.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TERow {
                            settingsToggle("AUTO-SAVE", isOn: $useDefaultExportFolder)
                        }

                        TERow(showDivider: false) {
                            settingsButton("REMOVE FOLDER", icon: "folder.badge.minus", color: TE.danger) {
                                showingClearFolderConfirmation = true
                            }
                        }
                    } else {
                        TERow(showDivider: false) {
                            settingsButton("SELECT FOLDER", icon: "folder.badge.plus") {
                                showingFolderPicker = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: exportFolderManager.hasDefaultFolder
                ? "Exports saved directly to this folder when auto-save is enabled."
                : "Set a default folder to save exports without the share sheet.")
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DATA EXPORT")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        Button { showingExportOptions = true } label: {
                            HStack {
                                Text("EXPORT VISITS")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Text("\(viewModel.allVisits.count)")
                                    .font(TE.mono(.caption2, weight: .medium))
                                    .foregroundStyle(TE.textMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(TE.textMuted.opacity(0.4))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    TERow(showDivider: false) {
                        Button { showingLocationPointsExportOptions = true } label: {
                            HStack {
                                Text("EXPORT POINTS")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Text("\(viewModel.locationPoints.count)")
                                    .font(TE.mono(.caption2, weight: .medium))
                                    .foregroundStyle(TE.textMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(TE.textMuted.opacity(0.4))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)

            if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
                TESectionFooter(text: "Files saved to \(exportFolderManager.selectedFolderName ?? "your folder").")
            } else {
                TESectionFooter(text: "Export as JSON, CSV, or Markdown.")
            }
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DATA IMPORT")

            TECard {
                VStack(spacing: 0) {
                    TERow(showDivider: false) {
                        settingsButton("IMPORT FILE", icon: "square.and.arrow.down") {
                            showingImportPicker = true
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Import visits or points from a previously exported JSON, CSV, or Markdown file.")
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DATA")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack {
                            Text("VISITS")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Text("\(viewModel.allVisits.count)")
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.textMuted)
                        }
                    }

                    TERow {
                        HStack {
                            Text("POINTS")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Text("\(viewModel.locationPoints.count)")
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.textMuted)
                        }
                    }

                    TERow(showDivider: false) {
                        settingsButton("CLEAR ALL DATA", icon: "trash", color: TE.danger) {
                            showingClearConfirmation = true
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Onboarding Section

    private var onboardingSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ONBOARDING")

            TECard {
                TERow(showDivider: false) {
                    settingsButton("REPLAY ONBOARDING", icon: "sparkles") {
                        hasCompletedOnboarding = false
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ABOUT")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack {
                            Text("VERSION")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.textMuted)
                        }
                    }

                    TERow(showDivider: false) {
                        HStack {
                            Text("STORAGE")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Text("ON-DEVICE ONLY")
                                .font(TE.mono(.caption2, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "All data stored locally. Never uploaded to any server.")
        }
    }

    // MARK: - Reusable Row Components

    private func settingsToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(TE.mono(.caption, weight: .medium))
                .tracking(1)
                .foregroundStyle(TE.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(TE.accent)
        }
    }

    private func settingsButton(_ label: String, icon: String, color: Color = TE.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(color)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
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

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let importResult = try viewModel.importData(from: url)
                importResultMessage = importResult.summary
                showingImportResult = true
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        case .failure(let error):
            importErrorMessage = error.localizedDescription
            showingImportError = true
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
