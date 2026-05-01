import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPaywall = false
    @State private var showingClearConfirmation = false
    @State private var showingImportPicker = false
    @State private var importResultMessage: String?
    @State private var showingImportResult = false
    @State private var importErrorMessage: String?
    @State private var showingImportError = false

    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("usesMetricDistanceUnits") private var usesMetricDistanceUnits = true
    @AppStorage("allowNetworkGeocoding") private var allowNetworkGeocoding = true
    @AppStorage("showOutliers") private var showOutliers = false

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        purchaseSection
                        trackingSection
                        unitsSection
                        mapDisplaySection
                        importSection
                        dataSection
                        onboardingSection
                        supportSection
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
            .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { viewModel.clearAllData() }
            } message: {
                Text("This will permanently delete all visit data and location points. This action cannot be undone.")
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
            TESectionHeader(title: "ISO.ME PRO")

            TECard {
                VStack(spacing: 0) {
                    if storeManager.isPurchased {
                        TERow(showDivider: false) {
                            HStack {
                                Circle()
                                    .fill(TE.success)
                                    .frame(width: 6, height: 6)
                                Text("EXPORT UNLOCKED")
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
                        TERow {
                            settingsButton("UNLOCK EXPORT", icon: "lock.open.fill") {
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
                TESectionFooter(text: "Tracking is free and unlimited. Unlock data export with a one-time purchase.")
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

                    TERow {
                        settingsToggle("START ON LAUNCH", isOn: $defaultLocationTrackingEnabled)
                    }

                    TERow {
                        HStack {
                            Text("DISTANCE FILTER")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.locationManager.distanceFilter },
                                set: { viewModel.locationManager.setDistanceFilter($0) }
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

                    TERow {
                        HStack {
                            Text("STOP AFTER")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { viewModel.locationManager.stopAfterHours },
                                set: { viewModel.locationManager.setStopAfterHours($0) }
                            )) {
                                Text("Never").tag(0.0)
                                Text("1h").tag(1.0)
                                Text("2h").tag(2.0)
                                Text("4h").tag(4.0)
                                Text("8h").tag(8.0)
                                Text("12h").tag(12.0)
                            }
                            .labelsHidden()
                            .tint(TE.accent)
                        }
                    }

                    TERow(showDivider: false) {
                        settingsToggle("LOCATION NAMES", isOn: $allowNetworkGeocoding)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Tracking records visits, significant changes, and a continuous high-accuracy path. Distance filter controls how often points are saved while moving. Stop After auto-stops as a safety net.")
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

    private func unitButton(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    // MARK: - Map Display Section

    private var mapDisplaySection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "MAP DISPLAY")

            TECard {
                TERow(showDivider: false) {
                    settingsToggle("SHOW GPS GLITCHES", isOn: $showOutliers)
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Points flagged as GPS glitches (sudden jumps that return to your path) are hidden by default. Turn on to inspect the raw data.")
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

    // MARK: - Support Section

    private var supportSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "SUPPORT")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        NavigationLink {
                            LogViewerView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TE.accent)
                                Text("VIEW LOGS")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TE.accent.opacity(0.5))
                            }
                        }
                    }

                    TERow(showDivider: false) {
                        Link(destination: discordInviteURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TE.accent)
                                Text("JOIN DISCORD")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TE.accent.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "View app activity logs or chat with the community.")
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
                            Text(AppInfo.versionDisplay)
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.textMuted)
                        }
                    }

                    TERow {
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

                    TERow {
                        settingsButton("SEND FEEDBACK", icon: "envelope") {
                            sendFeedbackEmail()
                        }
                    }

                    TERow {
                        Link(destination: URL(string: "https://isome.isolated.tech/privacy")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TE.accent)
                                Text("PRIVACY POLICY")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TE.accent.opacity(0.5))
                            }
                        }
                    }

                    TERow(showDivider: false) {
                        Link(destination: URL(string: "https://isome.isolated.tech/terms")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(TE.accent)
                                Text("TERMS OF SERVICE")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(TE.accent.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "All data stored locally. Never uploaded to any server.")
        }
    }

    // MARK: - Feedback Email

    private func sendFeedbackEmail() {
        let subject = "iso.me Feedback"
        let footer = """

        ---
        App: iso.me \(AppInfo.versionDisplay)
        Platform: \(AppInfo.platformDisplay)
        Device: \(AppInfo.deviceModel)
        """
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = footer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? footer
        if let url = URL(string: "mailto:cody@isolated.tech?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Reusable Row Components

    private func settingsToggle(_ label: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(TE.mono(.caption, weight: .medium))
                .tracking(1)
                .foregroundStyle(TE.textPrimary)
        }
        .toggleStyle(TEToggleStyle())
    }

    private func settingsButton(_ label: LocalizedStringKey, icon: String, color: Color = TE.accent, action: @escaping () -> Void) -> some View {
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
