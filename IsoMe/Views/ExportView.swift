import SwiftUI
import SwiftData

struct ExportView: View {
    @Bindable var viewModel: LocationViewModel
    @StateObject private var exportFolderManager = ExportFolderManager.shared
    @StateObject private var dailyScheduler = DailyExportScheduler.shared
    @ObservedObject private var storeManager = StoreManager.shared

    @State private var options = ExportOptions()
    @State private var showingPaywall = false
    @State private var showingFolderPicker = false
    @State private var showingClearFolderConfirmation = false
    @State private var exportSuccessMessage: String?
    @State private var showingExportSuccess = false
    @State private var dailyTimeBinding = Date()

    @AppStorage("useDefaultExportFolder") private var useDefaultExportFolder = true
    @AppStorage("exportFilenamePattern") private var filenamePattern = FilenameTemplate.defaultPattern

    private var filteredVisits: [Visit] {
        options.filterVisits(viewModel.allVisits)
    }

    private var filteredPoints: [LocationPoint] {
        options.filterPoints(viewModel.locationPoints)
    }

    private var totalCount: Int {
        switch options.dataKind {
        case .visits: return filteredVisits.count
        case .points: return filteredPoints.count
        case .all: return filteredVisits.count + filteredPoints.count
        }
    }

    private var splitFileCount: Int {
        guard options.splitByDay else { return totalCount > 0 ? 1 : 0 }
        return options.groupByDay(visits: filteredVisits, points: filteredPoints).count
    }

    private var showsVisitFields: Bool {
        options.dataKind == .visits || options.dataKind == .all
    }

    private var showsPointFields: Bool {
        options.dataKind == .points || options.dataKind == .all
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                if storeManager.isPurchased {
                    ScrollView {
                        VStack(spacing: 0) {
                            formatSection
                            dataKindSection
                            exportFolderSection
                            if exportFolderManager.hasDefaultFolder {
                                dailyExportSection
                            }
                            filenameSection
                            outputSection
                            dateRangeSection
                            timeOfDaySection
                            filtersSection
                            if showsVisitFields { visitFieldsSection }
                            if showsPointFields { pointFieldsSection }
                            Spacer().frame(height: 110)
                        }
                    }

                    VStack {
                        Spacer()
                        exportFooter
                    }
                } else {
                    lockedState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("EXPORT")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(TE.textMuted)
                }
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
            .sheet(isPresented: $showingFolderPicker) {
                FolderPicker { url in
                    if let url = url {
                        exportFolderManager.setDefaultFolder(url)
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeManager: storeManager)
            }
        }
    }

    // MARK: - Locked state

    private var lockedState: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(TE.textMuted)

            Text("EXPORT LOCKED")
                .font(TE.mono(.caption, weight: .bold))
                .tracking(2)
                .foregroundStyle(TE.textPrimary)

            Text("Tracking is free and unlimited. Unlock data export with a one-time purchase.")
                .font(TE.mono(.caption2, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)

            Button {
                showingPaywall = true
            } label: {
                Text("UNLOCK EXPORT")
                    .font(TE.mono(.caption, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 44)
                    .background(TE.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("RESTORE PURCHASE")
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(TE.textMuted)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Format

    private var formatSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "FORMAT")

            TECard {
                HStack(spacing: 0) {
                    segmentedButton("JSON", isSelected: options.format == .json) { options.format = .json }
                    Rectangle().fill(TE.border).frame(width: 1)
                    segmentedButton("CSV", isSelected: options.format == .csv) { options.format = .csv }
                    Rectangle().fill(TE.border).frame(width: 1)
                    segmentedButton("MARKDOWN", isSelected: options.format == .markdown) { options.format = .markdown }
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Data Kind

    private var dataKindSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DATA")

            TECard {
                HStack(spacing: 0) {
                    segmentedButton("VISITS", isSelected: options.dataKind == .visits) { options.dataKind = .visits }
                    Rectangle().fill(TE.border).frame(width: 1)
                    segmentedButton("POINTS", isSelected: options.dataKind == .points) { options.dataKind = .points }
                    Rectangle().fill(TE.border).frame(width: 1)
                    segmentedButton("ALL", isSelected: options.dataKind == .all) { options.dataKind = .all }
                }
                .frame(height: 44)
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Export Folder

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
                            toggleRow("AUTO-SAVE", isOn: $useDefaultExportFolder)
                        }

                        TERow(showDivider: false) {
                            Button {
                                showingClearFolderConfirmation = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.badge.minus")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(TE.danger)
                                    Text("REMOVE FOLDER")
                                        .font(TE.mono(.caption, weight: .medium))
                                        .tracking(1)
                                        .foregroundStyle(TE.danger)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(TE.danger.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        TERow(showDivider: false) {
                            Button {
                                showingFolderPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(TE.accent)
                                    Text("SELECT FOLDER")
                                        .font(TE.mono(.caption, weight: .medium))
                                        .tracking(1)
                                        .foregroundStyle(TE.accent)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(TE.accent.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: exportFolderManager.hasDefaultFolder
                ? "Exports save directly to this folder when auto-save is on. Otherwise the share sheet opens."
                : "Set a default folder to save exports without the share sheet.")
        }
    }

    // MARK: - Daily Export

    private var dailyExportSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DAILY EXPORT")

            TECard {
                VStack(spacing: 0) {
                    TERow(showDivider: dailyScheduler.isEnabled) {
                        toggleRow("ENABLE", isOn: Binding(
                            get: { dailyScheduler.isEnabled },
                            set: { dailyScheduler.isEnabled = $0 }
                        ))
                    }

                    if dailyScheduler.isEnabled {
                        TERow {
                            HStack {
                                Text("TIME")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                DatePicker("", selection: $dailyTimeBinding, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .tint(TE.accent)
                                    .onChange(of: dailyTimeBinding) { _, newValue in
                                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                        dailyScheduler.hour = comps.hour ?? 21
                                        dailyScheduler.minute = comps.minute ?? 0
                                    }
                            }
                        }

                        TERow {
                            HStack {
                                Text("FORMAT")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { dailyScheduler.format },
                                    set: { dailyScheduler.format = $0 }
                                )) {
                                    Text("JSON").tag(ExportFormat.json)
                                    Text("CSV").tag(ExportFormat.csv)
                                    Text("MARKDOWN").tag(ExportFormat.markdown)
                                }
                                .labelsHidden()
                                .tint(TE.accent)
                            }
                        }

                        TERow {
                            HStack {
                                Text("DATA")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { dailyScheduler.dataKind },
                                    set: { dailyScheduler.dataKind = $0 }
                                )) {
                                    Text("VISITS").tag(ExportOptions.DataKind.visits)
                                    Text("POINTS").tag(ExportOptions.DataKind.points)
                                    Text("ALL").tag(ExportOptions.DataKind.all)
                                }
                                .labelsHidden()
                                .tint(TE.accent)
                            }
                        }

                        TERow {
                            HStack {
                                Text("LAST RUN")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textMuted)
                                Spacer()
                                Text(lastRunText)
                                    .font(TE.mono(.caption2, weight: .medium))
                                    .foregroundStyle(TE.textPrimary)
                            }
                        }

                        TERow(showDivider: false) {
                            Button {
                                Task { await dailyScheduler.runNow() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(TE.accent)
                                    Text("RUN NOW")
                                        .font(TE.mono(.caption, weight: .medium))
                                        .tracking(1)
                                        .foregroundStyle(TE.accent)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(TE.accent.opacity(0.5))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: dailyScheduler.isEnabled
                ? "iOS schedules background runs near this time, but cannot guarantee them. The export also runs the next time you open the app if it's overdue."
                : "Save a fresh export to your folder once per day, automatically.")
        }
        .onAppear {
            var comps = DateComponents()
            comps.hour = dailyScheduler.hour
            comps.minute = dailyScheduler.minute
            dailyTimeBinding = Calendar.current.date(from: comps) ?? Date()
        }
    }

    private var lastRunText: String {
        guard let last = dailyScheduler.lastRun else { return "NEVER" }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: last)
    }

    // MARK: - Filename

    private var filenameSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "FILENAME")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack(spacing: 0) {
                            presetButton("READABLE", isSelected: filenamePattern == FilenameTemplate.readablePattern) {
                                filenamePattern = FilenameTemplate.readablePattern
                            }
                            Rectangle().fill(TE.border).frame(width: 1)
                            presetButton("COMPACT", isSelected: filenamePattern == FilenameTemplate.compactPattern) {
                                filenamePattern = FilenameTemplate.compactPattern
                            }
                        }
                        .frame(height: 36)
                    }

                    TERow {
                        TextField("", text: $filenamePattern)
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }

                    TERow(showDivider: false) {
                        HStack {
                            Text("PREVIEW")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            Spacer()
                            Text(filenamePreview)
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.accent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Tokens: \(FilenameTemplate.allTokens.map { $0.token }.joined(separator: " "))")
        }
    }

    private var filenamePreview: String {
        FilenameTemplate.resolve(
            pattern: filenamePattern,
            dataKind: options.dataKind,
            format: options.format
        )
    }

    private func presetButton(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    // MARK: - Output

    private var outputSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "OUTPUT")

            TECard {
                TERow(showDivider: false) {
                    toggleRow("ONE FILE PER DAY", isOn: $options.splitByDay)
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: options.splitByDay
                ? "Each calendar day in the range becomes its own file. Use {date} or {day} in the filename to keep them distinct."
                : "All filtered data is condensed into a single file.")
        }
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DATE RANGE")

            TECard {
                VStack(spacing: 0) {
                    ForEach(Array(ExportOptions.DateRangePreset.allCases.enumerated()), id: \.element.id) { idx, preset in
                        let isLast = idx == ExportOptions.DateRangePreset.allCases.count - 1
                                && options.datePreset != .custom
                        TERow(showDivider: !isLast) {
                            Button {
                                options.datePreset = preset
                            } label: {
                                HStack {
                                    Text(LocalizedStringKey(preset.label))
                                        .font(TE.mono(.caption, weight: .medium))
                                        .tracking(1)
                                        .foregroundStyle(TE.textPrimary)
                                    Spacer()
                                    if options.datePreset == preset {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(TE.accent)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if options.datePreset == .custom {
                        TERow {
                            HStack {
                                Text("FROM")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                DatePicker("", selection: $options.customStart, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(TE.accent)
                            }
                        }
                        TERow(showDivider: false) {
                            HStack {
                                Text("TO")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                DatePicker("", selection: $options.customEnd, displayedComponents: [.date])
                                    .labelsHidden()
                                    .tint(TE.accent)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Limit the export to a specific window of time.")
        }
    }

    // MARK: - Time of day

    private var timeOfDaySection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "TIME OF DAY")

            TECard {
                VStack(spacing: 0) {
                    TERow(showDivider: options.timeOfDayEnabled) {
                        toggleRow("ENABLE", isOn: $options.timeOfDayEnabled)
                    }

                    if options.timeOfDayEnabled {
                        TERow {
                            HStack {
                                Text("START")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                DatePicker("", selection: $options.timeOfDayStart, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .tint(TE.accent)
                            }
                        }
                        TERow(showDivider: false) {
                            HStack {
                                Text("END")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                DatePicker("", selection: $options.timeOfDayEnd, displayedComponents: [.hourAndMinute])
                                    .labelsHidden()
                                    .tint(TE.accent)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Only include data captured between these hours each day. Wraps midnight if end is before start.")
        }
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "FILTERS")

            TECard {
                VStack(spacing: 0) {
                    if showsVisitFields {
                        TERow {
                            toggleRow("ONLY COMPLETED VISITS", isOn: $options.onlyCompletedVisits)
                        }
                        TERow {
                            HStack {
                                Text("MIN DURATION")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Picker("", selection: $options.minVisitDurationMinutes) {
                                    Text("None").tag(0.0)
                                    Text("5m").tag(5.0)
                                    Text("15m").tag(15.0)
                                    Text("30m").tag(30.0)
                                    Text("1h").tag(60.0)
                                }
                                .labelsHidden()
                                .tint(TE.accent)
                            }
                        }
                    }
                    if showsPointFields {
                        TERow {
                            toggleRow("EXCLUDE GPS GLITCHES", isOn: $options.excludeOutliers)
                        }
                        TERow(showDivider: false) {
                            HStack {
                                Text("ACCURACY CAP")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)
                                Spacer()
                                Picker("", selection: $options.maxAccuracyMeters) {
                                    Text("Any").tag(0.0)
                                    Text("≤ 10m").tag(10.0)
                                    Text("≤ 25m").tag(25.0)
                                    Text("≤ 50m").tag(50.0)
                                    Text("≤ 100m").tag(100.0)
                                }
                                .labelsHidden()
                                .tint(TE.accent)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Visit Fields

    private var visitFieldsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VISIT FIELDS")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        toggleRow("LOCATION NAME", isOn: $options.includeVisitLocationName)
                    }
                    TERow {
                        toggleRow("ADDRESS", isOn: $options.includeVisitAddress)
                    }
                    TERow {
                        toggleRow("DURATION", isOn: $options.includeVisitDuration)
                    }
                    TERow {
                        toggleRow("COORDINATES", isOn: $options.includeVisitCoordinates)
                    }
                    TERow(showDivider: false) {
                        toggleRow("NOTES", isOn: $options.includeVisitNotes)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Arrival and departure timestamps are always included.")
        }
    }

    // MARK: - Point Fields

    private var pointFieldsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "POINT FIELDS")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        toggleRow("ALTITUDE", isOn: $options.includePointAltitude)
                    }
                    TERow {
                        toggleRow("SPEED", isOn: $options.includePointSpeed)
                    }
                    TERow {
                        toggleRow("ACCURACY", isOn: $options.includePointAccuracy)
                    }
                    TERow(showDivider: false) {
                        toggleRow("OUTLIER FLAG", isOn: $options.includePointOutlierFlag)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Timestamp and coordinates are always included.")
        }
    }

    // MARK: - Footer

    private var exportFooter: some View {
        VStack(spacing: 8) {
            Button {
                runExport()
            } label: {
                Text(exportButtonLabel)
                    .font(TE.mono(.caption, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(totalCount == 0 ? TE.textMuted.opacity(0.3) : TE.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(totalCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [TE.surface.opacity(0), TE.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }

    private var exportButtonLabel: LocalizedStringKey {
        if totalCount == 0 { return "NOTHING TO EXPORT" }
        if options.splitByDay {
            let n = splitFileCount
            if n == 0 { return "NOTHING TO EXPORT" }
            if n == 1 { return "EXPORT 1 FILE" }
            return "EXPORT \(n) FILES"
        }
        return "EXPORT"
    }

    // MARK: - Reusable bits

    private func segmentedButton(_ title: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
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

    private func toggleRow(_ label: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(TE.mono(.caption, weight: .medium))
                .tracking(1)
                .foregroundStyle(TE.textPrimary)
        }
        .toggleStyle(TEToggleStyle())
    }

    // MARK: - Actions

    private func runExport() {
        if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
            do {
                let urls = try ExportService.saveToDefaultFolder(
                    visits: viewModel.allVisits,
                    points: viewModel.locationPoints,
                    options: options,
                    filenamePattern: filenamePattern
                )
                if urls.count == 1, let url = urls.first {
                    exportSuccessMessage = "Saved to \(url.lastPathComponent)"
                } else if let folder = urls.first?.deletingLastPathComponent().lastPathComponent {
                    exportSuccessMessage = "Saved \(urls.count) files to \(folder)"
                } else {
                    exportSuccessMessage = "Saved \(urls.count) files"
                }
                showingExportSuccess = true
            } catch {
                viewModel.exportError = error.localizedDescription
            }
        } else {
            do {
                try ExportService.share(
                    visits: viewModel.allVisits,
                    points: viewModel.locationPoints,
                    options: options,
                    filenamePattern: filenamePattern
                )
            } catch {
                viewModel.exportError = error.localizedDescription
            }
        }
    }
}

#Preview {
    ExportView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}
