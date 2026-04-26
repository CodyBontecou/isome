import SwiftUI
import SwiftData
import ActivityKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var viewModel: LocationViewModel
    @StateObject private var exportFolderManager = ExportFolderManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPaywall = false
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
    @State private var showAdvanced = false

    @AppStorage("autoStartOnActivity") private var autoStartOnActivity = false
    @AppStorage("autoStartOnDistance") private var autoStartOnDistance = false
    @AppStorage("activityTriggerDriving") private var activityTriggerDriving = true
    @AppStorage("activityTriggerCycling") private var activityTriggerCycling = true
    @AppStorage("activityTriggerRunning") private var activityTriggerRunning = true
    @AppStorage("activityTriggerWalking") private var activityTriggerWalking = true
    @AppStorage("activityMinimumConfidence") private var activityMinimumConfidence = MotionConfidenceThreshold.medium.rawValue
    @AppStorage("activityPromptCooldownMinutes") private var activityPromptCooldownMinutes = 30.0
    @AppStorage("useDefaultExportFolder") private var useDefaultExportFolder = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("usesMetricDistanceUnits") private var usesMetricDistanceUnits = true
    @AppStorage("allowNetworkGeocoding") private var allowNetworkGeocoding = true
    @AppStorage("showOutliers") private var showOutliers = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()
                settingsScrollContent
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear all data?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { viewModel.clearAllData() }
            } message: {
                Text("This will permanently delete all visit data and location points. This action cannot be undone.")
            }
            .alert("Remove default folder?", isPresented: $showingClearFolderConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) { exportFolderManager.clearDefaultFolder() }
            } message: {
                Text("Exports will use the share sheet instead of saving directly to a folder.")
            }
            .alert("Export complete", isPresented: $showingExportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = exportSuccessMessage { Text(message) }
            }
            .alert("Import complete", isPresented: $showingImportResult) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = importResultMessage { Text(message) }
            }
            .alert("Import failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message = importErrorMessage { Text(message) }
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
                    if let url = url { exportFolderManager.setDefaultFolder(url) }
                }
            }
            .onChange(of: usesMetricDistanceUnits) { _, _ in
                viewModel.locationManager.refreshDistanceUnitPreference()
            }
            .onChange(of: activityMinimumConfidence) { _, newValue in
                LogManager.shared.info("[Movement] Updated prompt sensitivity to \(newValue).")
            }
            .onChange(of: activityPromptCooldownMinutes) { _, newValue in
                LogManager.shared.info("[Movement] Updated prompt cooldown to \(Int(newValue)) minutes.")
            }
            .onChange(of: activityTriggerDriving) { _, isEnabled in
                LogManager.shared.info("[Movement] Driving trigger \(isEnabled ? "enabled" : "disabled").")
            }
            .onChange(of: activityTriggerCycling) { _, isEnabled in
                LogManager.shared.info("[Movement] Cycling trigger \(isEnabled ? "enabled" : "disabled").")
            }
            .onChange(of: activityTriggerRunning) { _, isEnabled in
                LogManager.shared.info("[Movement] Running trigger \(isEnabled ? "enabled" : "disabled").")
            }
            .onChange(of: activityTriggerWalking) { _, isEnabled in
                LogManager.shared.info("[Movement] Walking trigger \(isEnabled ? "enabled" : "disabled").")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeManager: storeManager)
            }
        }
    }

    @ViewBuilder
    private var settingsScrollContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical) {
                VStack(spacing: DS.Spacing.lg) {
                    if !storeManager.isPurchased {
                        subscriptionSection
                    } else {
                        purchasedSection
                    }
                    trackingSection
                    permissionSection
                    automationSection
                    mapDisplaySection
                    unitsSection
                    exportFolderSection
                    exportSection
                        .id("exportSection")
                    importSection
                    dataSection
                    onboardingSection
                    aboutSection
                    advancedSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            #if DEBUG
            .onAppear {
                if ProcessInfo.processInfo.arguments.contains("--scroll-to-export") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.none) {
                            scrollProxy.scrollTo("exportSection", anchor: .top)
                        }
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Subscription / Pro

    private var subscriptionSection: some View {
        section(title: "iso.me Pro", footer: "Tracking is always free. One-time purchase to unlock data export.") {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    CategoryIcon(symbol: "lock.open.fill", palette: .purple, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock data export")
                            .font(DS.Font.headline())
                            .foregroundStyle(DS.Color.textPrimary)
                        Text("Export visits, points, and combined data")
                            .font(DS.Font.caption())
                            .foregroundStyle(DS.Color.textMuted)
                    }
                    Spacer(minLength: 0)
                }

                PrimaryButton(title: "View pricing") {
                    showingPaywall = true
                }

                Button {
                    Task { await storeManager.restorePurchases() }
                } label: {
                    Text("Restore purchase")
                        .font(DS.Font.body(.medium))
                        .foregroundStyle(DS.Color.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var purchasedSection: some View {
        section(title: "iso.me Pro") {
            HStack(spacing: DS.Spacing.md) {
                CategoryIcon(symbol: "checkmark.seal.fill", palette: .green, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pro unlocked")
                        .font(DS.Font.headline())
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Data export available")
                        .font(DS.Font.caption())
                        .foregroundStyle(DS.Color.textMuted)
                }
                Spacer(minLength: 0)
                StatusDot(state: .on)
            }
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        section(title: "Tracking", footer: "Auto-detect uses CLVisit. Precise routes record your full path between visits.") {
            VStack(spacing: 0) {
                DSRow {
                    toggleRow(
                        symbol: "location.fill",
                        palette: .green,
                        title: "Auto-detect places",
                        subtitle: "Battery friendly visit detection",
                        isOn: Binding(
                            get: { viewModel.locationManager.isTrackingEnabled },
                            set: { newValue in
                                if newValue { viewModel.enableTracking() } else { viewModel.disableTracking() }
                            }
                        )
                    )
                }

                DSRow {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "waveform.path.ecg", palette: .purple, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Live Activity")
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(liveActivityStatus)
                                .font(DS.Font.caption())
                                .foregroundStyle(DS.Color.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                }

                DSRow {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "timer", palette: .peach, size: 36)
                        Text("Auto-off")
                            .font(DS.Font.body(.medium))
                            .foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { viewModel.locationManager.trackingAutoOffHours },
                            set: {
                                viewModel.locationManager.trackingAutoOffHours = $0
                                UserDefaults.standard.set($0, forKey: TrackingStorageKeys.autoOffHours)
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
                        .tint(DS.Color.accent)
                    }
                }

                DSRow(showDivider: false) {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "ruler", palette: .blue, size: 36)
                        Text("Distance filter")
                            .font(DS.Font.body(.medium))
                            .foregroundStyle(DS.Color.textPrimary)
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
                        .tint(DS.Color.accent)
                    }
                }
            }
        }
    }

    private var liveActivityStatus: String {
        if !ActivityAuthorizationInfo().areActivitiesEnabled { return "Disabled in system settings" }
        return LiveActivityManager.shared.isActivityActive ? "Active" : "Ready"
    }

    // MARK: - Permission

    private var permissionSection: some View {
        section(title: "Permission") {
            VStack(spacing: 0) {
                DSRow(showDivider: !viewModel.locationManager.hasAlwaysPermission) {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "lock.shield.fill", palette: permissionPalette, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location access")
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.textPrimary)
                            Text(permissionStatusText)
                                .font(DS.Font.caption())
                                .foregroundStyle(permissionStatusColor)
                        }
                        Spacer(minLength: 0)
                    }
                }

                if !viewModel.locationManager.hasAlwaysPermission {
                    DSRow(showDivider: false) {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                CategoryIcon(symbol: "gearshape.fill", palette: .purple, size: 36)
                                Text("Open system settings")
                                    .font(DS.Font.body(.medium))
                                    .foregroundStyle(DS.Color.accent)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DS.Color.textMuted)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var permissionStatusText: String {
        switch viewModel.locationManager.authorizationStatus {
        case .notDetermined: return String(localized: "Not set")
        case .restricted: return String(localized: "Restricted")
        case .denied: return String(localized: "Denied")
        case .authorizedWhenInUse: return String(localized: "When in use")
        case .authorizedAlways: return String(localized: "Always")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private var permissionStatusColor: Color {
        switch viewModel.locationManager.authorizationStatus {
        case .authorizedAlways: return DS.Color.accentGreen
        case .authorizedWhenInUse: return DS.Color.warning
        case .denied, .restricted: return DS.Color.danger
        default: return DS.Color.textMuted
        }
    }

    private var permissionPalette: DS.Palette {
        switch viewModel.locationManager.authorizationStatus {
        case .authorizedAlways: return .green
        case .denied, .restricted: return .peach
        default: return .blue
        }
    }

    // MARK: - Automation

    private var automationSection: some View {
        section(
            title: "Movement detection",
            footer: autoStartOnActivity && !hasAnyMovementTriggerEnabled
                ? "Movement prompts are enabled, but all movement types are off. Enable at least one trigger."
                : "When tracking is off, movement detection can prompt before tracking starts."
        ) {
            VStack(spacing: 0) {
                DSRow {
                    toggleRow(
                        symbol: "bell.badge.fill",
                        palette: .purple,
                        title: "Prompt on movement",
                        subtitle: "Notify before auto-tracking",
                        isOn: Binding(
                            get: { autoStartOnActivity },
                            set: { newValue in
                                autoStartOnActivity = newValue
                                viewModel.locationManager.setAutoStartOnActivity(newValue)
                            }
                        )
                    )
                }

                if autoStartOnActivity {
                    DSRow {
                        HStack(spacing: DS.Spacing.md) {
                            CategoryIcon(symbol: "slider.horizontal.3", palette: .blue, size: 36)
                            Text("Sensitivity")
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.textPrimary)
                            Spacer()
                            Picker("", selection: $activityMinimumConfidence) {
                                ForEach(MotionConfidenceThreshold.allCases, id: \.rawValue) { threshold in
                                    Text(threshold.title).tag(threshold.rawValue)
                                }
                            }
                            .labelsHidden()
                            .tint(DS.Color.accent)
                        }
                    }

                    DSRow {
                        compactToggle(symbol: "car.fill", palette: .blue, title: "Driving", isOn: $activityTriggerDriving)
                    }
                    DSRow {
                        compactToggle(symbol: "bicycle", palette: .peach, title: "Cycling", isOn: $activityTriggerCycling)
                    }
                    DSRow {
                        compactToggle(symbol: "figure.run", palette: .green, title: "Running", isOn: $activityTriggerRunning)
                    }
                    DSRow {
                        compactToggle(symbol: "figure.walk", palette: .green, title: "Walking", isOn: $activityTriggerWalking)
                    }

                    DSRow {
                        HStack(spacing: DS.Spacing.md) {
                            CategoryIcon(symbol: "hourglass", palette: .peach, size: 36)
                            Text("Cooldown")
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.textPrimary)
                            Spacer()
                            Picker("", selection: $activityPromptCooldownMinutes) {
                                Text("5m").tag(5.0)
                                Text("15m").tag(15.0)
                                Text("30m").tag(30.0)
                                Text("60m").tag(60.0)
                            }
                            .labelsHidden()
                            .tint(DS.Color.accent)
                        }
                    }
                }

                DSRow {
                    toggleRow(
                        symbol: "figure.strengthtraining.traditional",
                        palette: .green,
                        title: "Auto-start on workout",
                        subtitle: "Begin tracking when a workout starts",
                        isOn: Binding(
                            get: { viewModel.locationManager.autoStartOnWorkout },
                            set: { viewModel.locationManager.setAutoStartOnWorkout($0) }
                        )
                    )
                }

                DSRow(showDivider: false) {
                    toggleRow(
                        symbol: "location.north.line.fill",
                        palette: .blue,
                        title: "Auto-start on distance",
                        subtitle: "Begin tracking after sustained movement",
                        isOn: Binding(
                            get: { autoStartOnDistance },
                            set: { newValue in
                                autoStartOnDistance = newValue
                                viewModel.locationManager.setAutoStartOnDistance(newValue)
                            }
                        )
                    )
                }
            }
        }
    }

    private var hasAnyMovementTriggerEnabled: Bool {
        activityTriggerDriving || activityTriggerCycling || activityTriggerRunning || activityTriggerWalking
    }

    // MARK: - Map display

    private var mapDisplaySection: some View {
        section(title: "Map & display", footer: "Names are looked up when available. Glitches are GPS jumps that return to your path.") {
            VStack(spacing: 0) {
                DSRow {
                    toggleRow(
                        symbol: "text.bubble.fill",
                        palette: .blue,
                        title: "Location names",
                        subtitle: "Reverse-geocode visits",
                        isOn: $allowNetworkGeocoding
                    )
                }

                DSRow(showDivider: false) {
                    toggleRow(
                        symbol: "exclamationmark.triangle.fill",
                        palette: .peach,
                        title: "Show GPS glitches",
                        subtitle: "Display outlier points on the map",
                        isOn: $showOutliers
                    )
                }
            }
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        section(title: "Units", footer: "Used in widgets, Live Activity, and throughout the app.") {
            HStack(spacing: DS.Spacing.sm) {
                unitButton("Metric", isSelected: usesMetricDistanceUnits) { usesMetricDistanceUnits = true }
                unitButton("US Standard", isSelected: !usesMetricDistanceUnits) { usesMetricDistanceUnits = false }
            }
        }
    }

    private func unitButton(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.body(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : DS.Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                        .fill(isSelected ? DS.Color.accent : DS.Color.divider.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export folder

    private var exportFolderSection: some View {
        section(
            title: "Export folder",
            footer: exportFolderManager.hasDefaultFolder
                ? "Files saved directly when auto-save is on."
                : "Set a folder to save exports without the share sheet."
        ) {
            VStack(spacing: 0) {
                if let folderName = exportFolderManager.selectedFolderName {
                    DSRow {
                        HStack(spacing: DS.Spacing.md) {
                            CategoryIcon(symbol: "folder.fill", palette: .brown, size: 36)
                            Text(folderName)
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") { showingFolderPicker = true }
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.accent)
                                .buttonStyle(.plain)
                        }
                    }
                    DSRow {
                        toggleRow(
                            symbol: "square.and.arrow.down.fill",
                            palette: .green,
                            title: "Auto-save",
                            subtitle: "Skip the share sheet",
                            isOn: $useDefaultExportFolder
                        )
                    }
                    DSRow(showDivider: false) {
                        Button {
                            showingClearFolderConfirmation = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                CategoryIcon(symbol: "folder.badge.minus", palette: .peach, size: 36)
                                Text("Remove folder")
                                    .font(DS.Font.body(.medium))
                                    .foregroundStyle(DS.Color.danger)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    DSRow(showDivider: false) {
                        Button {
                            showingFolderPicker = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                CategoryIcon(symbol: "folder.badge.plus", palette: .brown, size: 36)
                                Text("Select folder")
                                    .font(DS.Font.body(.medium))
                                    .foregroundStyle(DS.Color.accent)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        section(
            title: "Data & export",
            footer: exportFolderManager.hasDefaultFolder && useDefaultExportFolder
                ? "Files saved to \(exportFolderManager.selectedFolderName ?? "your folder")."
                : "Pick a format, then choose what to export."
        ) {
            VStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    formatChip(.json, label: "JSON", symbol: "curlybraces", palette: .purple)
                    formatChip(.csv, label: "CSV", symbol: "tablecells.fill", palette: .green)
                    formatChip(.markdown, label: "Markdown", symbol: "doc.richtext.fill", palette: .blue)
                }

                VStack(spacing: 0) {
                    DSRow {
                        exportActionRow(symbol: "mappin.and.ellipse", palette: .purple, title: "Export visits", count: viewModel.allVisits.count) {
                            exportVisits(format: exportFormat)
                        }
                    }
                    DSRow {
                        exportActionRow(symbol: "point.topleft.down.to.point.bottomright.curvepath", palette: .green, title: "Export points", count: viewModel.locationPoints.count) {
                            exportLocationPoints(format: exportFormat)
                        }
                    }
                    DSRow(showDivider: false) {
                        exportActionRow(symbol: "square.stack.3d.up.fill", palette: .blue, title: "Export everything", count: viewModel.allVisits.count + viewModel.locationPoints.count) {
                            exportAllData(format: exportFormat)
                        }
                    }
                }
            }
        }
    }

    private func formatChip(_ format: ExportFormat, label: LocalizedStringKey, symbol: String, palette: DS.Palette) -> some View {
        let isSelected = exportFormat == format
        return Button {
            exportFormat = format
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                CategoryIcon(symbol: symbol, palette: palette, size: 36)
                Text(label)
                    .font(DS.Font.caption(isSelected ? .semibold : .medium))
                    .foregroundStyle(DS.Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                    .fill(isSelected ? palette.tile : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                            .stroke(isSelected ? palette.icon.opacity(0.4) : DS.Color.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func exportActionRow(symbol: String, palette: DS.Palette, title: LocalizedStringKey, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                CategoryIcon(symbol: symbol, palette: palette, size: 36)
                Text(title)
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.textPrimary)
                Spacer()
                Text("\(count)")
                    .font(DS.Font.caption(.medium))
                    .foregroundStyle(DS.Color.textMuted)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.textMuted)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import

    private var importSection: some View {
        section(title: "Data import", footer: "Restore visits or points from a previously exported file.") {
            DSRow(showDivider: false) {
                Button {
                    showingImportPicker = true
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "square.and.arrow.down", palette: .blue, size: 36)
                        Text("Import file")
                            .font(DS.Font.body(.medium))
                            .foregroundStyle(DS.Color.accent)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        section(title: "Data") {
            VStack(spacing: 0) {
                DSRow {
                    statRow(symbol: "mappin.and.ellipse", palette: .purple, title: "Visits", value: viewModel.allVisits.count)
                }
                DSRow {
                    statRow(symbol: "point.topleft.down.to.point.bottomright.curvepath", palette: .green, title: "Location points", value: viewModel.locationPoints.count)
                }
                DSRow(showDivider: false) {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            CategoryIcon(symbol: "trash.fill", palette: .peach, size: 36)
                            Text("Clear all data")
                                .font(DS.Font.body(.semibold))
                                .foregroundStyle(DS.Color.danger)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statRow(symbol: String, palette: DS.Palette, title: LocalizedStringKey, value: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            CategoryIcon(symbol: symbol, palette: palette, size: 36)
            Text(title)
                .font(DS.Font.body(.medium))
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            Text("\(value)")
                .font(DS.Font.body(.semibold))
                .foregroundStyle(DS.Color.textPrimary)
                .monospacedDigit()
        }
    }

    // MARK: - Onboarding

    private var onboardingSection: some View {
        section(title: "Onboarding") {
            DSRow(showDivider: false) {
                Button {
                    hasCompletedOnboarding = false
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "sparkles", palette: .purple, size: 36)
                        Text("Replay onboarding")
                            .font(DS.Font.body(.medium))
                            .foregroundStyle(DS.Color.accent)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        section(title: "About", footer: "All data stored locally. Never uploaded to any server.") {
            VStack(spacing: 0) {
                DSRow {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "app.badge.fill", palette: .purple, size: 36)
                        Text("Version")
                            .font(DS.Font.body(.medium))
                            .foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                        Text(AppInfo.versionDisplay)
                            .font(DS.Font.caption(.medium))
                            .foregroundStyle(DS.Color.textMuted)
                            .monospaced()
                    }
                }

                DSRow {
                    HStack(spacing: DS.Spacing.md) {
                        CategoryIcon(symbol: "lock.shield.fill", palette: .green, size: 36)
                        Text("Storage")
                            .font(DS.Font.body(.medium))
                            .foregroundStyle(DS.Color.textPrimary)
                        Spacer()
                        Text("On-device only")
                            .font(DS.Font.caption(.medium))
                            .foregroundStyle(DS.Color.accentGreen)
                    }
                }

                DSRow {
                    Button {
                        sendFeedbackEmail()
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            CategoryIcon(symbol: "envelope.fill", palette: .peach, size: 36)
                            Text("Send feedback")
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.accent)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }

                DSRow {
                    externalLinkRow(symbol: "hand.raised.fill", palette: .blue, title: "Privacy policy", url: "https://isome.isolated.tech/privacy")
                }

                DSRow(showDivider: false) {
                    externalLinkRow(symbol: "doc.text.fill", palette: .blue, title: "Terms of service", url: "https://isome.isolated.tech/terms")
                }
            }
        }
    }

    private func externalLinkRow(symbol: String, palette: DS.Palette, title: LocalizedStringKey, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: DS.Spacing.md) {
                CategoryIcon(symbol: symbol, palette: palette, size: 36)
                Text(title)
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.accent)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.textMuted)
            }
        }
    }

    // MARK: - Advanced (debug)

    @ViewBuilder
    private var advancedSection: some View {
        #if DEBUG
        section(title: "Advanced") {
            VStack(spacing: 0) {
                DSRow(showDivider: showAdvanced) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            CategoryIcon(symbol: "wrench.and.screwdriver.fill", palette: .brown, size: 36)
                            Text("Developer tools")
                                .font(DS.Font.body(.medium))
                                .foregroundStyle(DS.Color.textPrimary)
                            Spacer()
                            Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Color.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if showAdvanced {
                    DSRow(showDivider: false) {
                        NavigationLink {
                            LogViewerView()
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                CategoryIcon(symbol: "doc.text.magnifyingglass", palette: .blue, size: 36)
                                Text("View logs")
                                    .font(DS.Font.body(.medium))
                                    .foregroundStyle(DS.Color.accent)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DS.Color.textMuted)
                            }
                        }
                    }
                }
            }
        }
        #else
        EmptyView()
        #endif
    }

    // MARK: - Section helper

    private func section<Content: View>(
        title: LocalizedStringKey,
        footer: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let body = content()
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: title)
            DSCard { body }
            if let footer {
                Text(footer)
                    .font(DS.Font.caption())
                    .foregroundStyle(DS.Color.textMuted)
                    .padding(.horizontal, DS.Spacing.xs)
            }
        }
    }

    private func toggleRow(
        symbol: String,
        palette: DS.Palette,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            CategoryIcon(symbol: symbol, palette: palette, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Font.caption())
                        .foregroundStyle(DS.Color.textMuted)
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DS.Color.accentGreen)
        }
    }

    private func compactToggle(symbol: String, palette: DS.Palette, title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: DS.Spacing.md) {
            CategoryIcon(symbol: symbol, palette: palette, size: 36)
            Text(title)
                .font(DS.Font.body(.medium))
                .foregroundStyle(DS.Color.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DS.Color.accentGreen)
        }
    }

    // MARK: - Feedback email

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

    // MARK: - Export helpers

    private func exportVisits(format: ExportFormat) {
        guard storeManager.isPurchased else { showingPaywall = true; return }
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
        guard storeManager.isPurchased else { showingPaywall = true; return }
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

    private func exportAllData(format: ExportFormat) {
        guard storeManager.isPurchased else { showingPaywall = true; return }
        if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
            do {
                let url = try ExportService.exportCombinedToDefaultFolder(
                    visits: viewModel.allVisits,
                    points: viewModel.locationPoints,
                    format: format
                )
                exportSuccessMessage = "Saved to \(url.lastPathComponent)"
                showingExportSuccess = true
            } catch {
                viewModel.exportError = error.localizedDescription
            }
        } else {
            viewModel.exportAllData(format: format)
        }
    }
}

#Preview {
    SettingsView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}

// MARK: - Folder picker

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
