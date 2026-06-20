import SwiftUI
import SwiftData
import MapKit
import Combine

struct OutingsView: View {
    @Bindable var viewModel: LocationViewModel
    let onShowOnMap: () -> Void

    @State private var sort: RecordingSessionSort = .newest
    @State private var hasLoadedSessions = false

    @AppStorage(RecordingSessionInferenceConfiguration.includesInferredSessionsKey)
    private var includesInferredSessions = RecordingSessionInferenceConfiguration.defaultIncludesInferredSessions
    @AppStorage(RecordingSessionInferenceConfiguration.gapPresetKey)
    private var inferenceGapPresetRawValue = RecordingSessionInferenceConfiguration.defaultGapPreset.rawValue
    @AppStorage(RecordingSessionInferenceConfiguration.minimumDurationPresetKey)
    private var inferenceMinimumDurationPresetRawValue = RecordingSessionInferenceConfiguration.defaultMinimumDurationPreset.rawValue
    @AppStorage(RecordingSessionInferenceConfiguration.minimumPointCountKey)
    private var inferenceMinimumPointCount = RecordingSessionInferenceConfiguration.defaultMinimumPointCountPreset.rawValue

    private var sessions: [RecordingSessionSummary] {
        sort.sorted(viewModel.recordingSessionSummaries(inferenceConfiguration: inferenceConfiguration))
    }

    private var inferenceConfiguration: RecordingSessionInferenceConfiguration {
        RecordingSessionInferenceConfiguration(
            includesInferredSessions: includesInferredSessions,
            gapThreshold: inferenceGapPreset.seconds,
            minimumDuration: inferenceMinimumDurationPreset.seconds,
            minimumPointCount: inferenceMinimumPointCount
        )
    }

    private var inferenceGapPreset: RecordingSessionGapPreset {
        RecordingSessionGapPreset(rawValue: inferenceGapPresetRawValue) ?? RecordingSessionInferenceConfiguration.defaultGapPreset
    }

    private var inferenceMinimumDurationPreset: RecordingSessionMinimumDurationPreset {
        RecordingSessionMinimumDurationPreset(rawValue: inferenceMinimumDurationPresetRawValue) ?? RecordingSessionInferenceConfiguration.defaultMinimumDurationPreset
    }

    private var totalDistance: Double {
        sessions.reduce(0) { $0 + $1.distanceMeters }
    }

    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                if !hasLoadedSessions && viewModel.totalLocationPointCount > 0 {
                    ProgressView("Building outings…")
                        .font(TE.mono(.caption, weight: .medium))
                        .foregroundStyle(TE.textMuted)
                } else if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            overviewSection
                            controlsSection
                            sessionsSection
                        }
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("OUTINGS")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(TE.textMuted)
                }
            }
            .task {
                refreshSessions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
                refreshSessions()
            }
        }
    }

    private var overviewSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "OVERVIEW")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack(spacing: 12) {
                            OutingOverviewMetric(
                                label: "OUTINGS",
                                value: "\(sessions.count)",
                                systemImage: "figure.walk.motion"
                            )

                            OutingOverviewMetric(
                                label: "DISTANCE",
                                value: DistanceFormatter.format(meters: totalDistance, usesMetric: usesMetricDistanceUnits),
                                systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                            )

                            OutingOverviewMetric(
                                label: "TIME",
                                value: RecordingSessionFormatter.duration(totalDuration),
                                systemImage: "clock"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Each start/stop recording becomes its own outing. Older GPS history can be auto-inferred using your saved inference settings.")
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "CONTROLS")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        HStack(spacing: 12) {
                            Text("ORDER")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)

                            Spacer()

                            Menu {
                                ForEach(RecordingSessionSort.allCases) { option in
                                    Button {
                                        sort = option
                                    } label: {
                                        if sort == option {
                                            Label(option.accessibilityLabel, systemImage: "checkmark")
                                        } else {
                                            Text(option.accessibilityLabel)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(sort.label.uppercased())
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2.weight(.bold))
                                }
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.accent)
                            }
                        }
                    }

                    TERow(showDivider: includesInferredSessions) {
                        Toggle(isOn: $includesInferredSessions) {
                            Text("INFERRED")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                        }
                        .toggleStyle(TEToggleStyle())
                    }

                    if includesInferredSessions {
                        TERow(showDivider: false) {
                            HStack(spacing: 12) {
                                Text("SPLIT AFTER")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.textPrimary)

                                Spacer()

                                Menu {
                                    ForEach(RecordingSessionGapPreset.allCases) { option in
                                        Button {
                                            inferenceGapPresetRawValue = option.rawValue
                                        } label: {
                                            if inferenceGapPreset == option {
                                                Label(option.settingsLabel, systemImage: "checkmark")
                                            } else {
                                                Text(option.settingsLabel)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(inferenceGapPreset.label.uppercased())
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2.weight(.bold))
                                    }
                                    .font(TE.mono(.caption2, weight: .semibold))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Inference controls only affect auto-generated outings from older GPS points. Exact start/stop recordings stay unchanged.")
        }
    }

    private var sessionsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "SESSIONS")

            LazyVStack(spacing: 10) {
                ForEach(sessions) { session in
                    NavigationLink {
                        RecordingSessionDetailView(
                            session: session,
                            viewModel: viewModel,
                            onShowOnMap: onShowOnMap
                        )
                    } label: {
                        RecordingSessionCard(
                            session: session,
                            usesMetricDistanceUnits: usesMetricDistanceUnits
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.walk.motion")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(TE.textMuted)

            Text("NO OUTINGS YET")
                .font(TE.mono(.caption, weight: .bold))
                .tracking(2)
                .foregroundStyle(TE.textPrimary)

            Text(emptyStateMessage)
                .font(TE.mono(.caption2, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)
        }
        .padding()
    }

    private var emptyStateMessage: String {
        if viewModel.locationManager.isTrackingEnabled {
            return "Tracking is active. Your outing will appear after iso.me saves the first location point."
        }

        if viewModel.totalLocationPointCount > 0 && !includesInferredSessions {
            return "Auto-inferred outings are turned off. Enable inferred outings to build outings from older GPS points."
        }

        if viewModel.totalLocationPointCount > 0 {
            return "No outings match your current inference settings. Lower the minimum duration or GPS point count in Settings."
        }

        return "Start tracking from the Map tab or your Shortcuts automation. Each start/stop recording will appear here as its own outing."
    }

    private var usesMetricDistanceUnits: Bool {
        let key = "usesMetricDistanceUnits"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func refreshSessions() {
        viewModel.loadRecordingSessions()
        viewModel.ensureAllLocationPointsLoaded()
        hasLoadedSessions = true
    }
}

private struct OutingOverviewMetric: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TE.accent)
                    .accessibilityHidden(true)

                Text(label)
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(TE.textMuted)
            }

            Text(value)
                .font(TE.mono(.caption, weight: .bold))
                .foregroundStyle(TE.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecordingSessionCard: View {
    let session: RecordingSessionSummary
    let usesMetricDistanceUnits: Bool

    var body: some View {
        TECard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(session.title.uppercased())
                                .font(TE.mono(.caption, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(TE.textPrimary)
                                .lineLimit(1)

                            if session.isActive {
                                OutingBadge(text: "LIVE", color: TE.success)
                            } else if session.isInferred {
                                OutingBadge(text: "INFERRED", color: TE.warning)
                            }
                        }

                        Text(session.formattedTimeRange)
                            .font(TE.mono(.caption2, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TE.textMuted.opacity(0.55))
                        .padding(.top, 2)
                }

                HStack(spacing: 8) {
                    OutingStatChip(
                        label: "DURATION",
                        value: RecordingSessionFormatter.duration(session.duration),
                        systemImage: "clock"
                    )
                    OutingStatChip(
                        label: "DISTANCE",
                        value: DistanceFormatter.format(meters: session.distanceMeters, usesMetric: usesMetricDistanceUnits),
                        systemImage: "ruler"
                    )
                    OutingStatChip(
                        label: "POINTS",
                        value: "\(session.pointCount)",
                        systemImage: "smallcircle.filled.circle"
                    )
                }
            }
            .padding(14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.title)
        .accessibilityValue(session.accessibilityValue)
        .accessibilityHint("Opens outing details.")
    }
}

private struct RecordingSessionDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: RecordingSessionSummary
    @Bindable var viewModel: LocationViewModel
    let onShowOnMap: () -> Void

    @StateObject private var exportFolderManager = ExportFolderManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var nameText = ""
    @State private var notesText = ""
    @State private var isRouteReplayEnabled = false
    @State private var isRouteReplayPlaying = false
    @State private var routeReplayProgress: Double = 1.0
    @State private var roadSnappedRoute: RoadSnappedRoute?
    @State private var showingPaywall = false
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isNotesFieldFocused: Bool

    @AppStorage("useDefaultExportFolder") private var useDefaultExportFolder = true
    @AppStorage("exportFilenamePattern") private var filenamePattern = FilenameTemplate.defaultPattern
    @AppStorage("outingDetailExportFormat") private var outingDetailExportFormatToken = ExportFormat.markdown.token
    @AppStorage("snapTravelPathToRoads") private var snapTravelPathToRoads = true
    @AppStorage("showStraightLinePathSegments") private var showStraightLinePathSegments = false

    private let routeReplayTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var visits: [Visit] {
        viewModel.visitsInDateRange(session.dateRange)
    }

    private var routeReplayPoints: [LocationPoint] {
        session.distancePoints
    }

    private var canReplayRoute: Bool {
        routeReplayPoints.count >= 2
    }

    private var routeReplaySnapshot: RouteReplaySnapshot? {
        RouteReplayCalculator.snapshot(points: routeReplayPoints, progress: routeReplayProgress)
    }

    private var roadSnappingSourceFingerprint: Int {
        RoadSnappedRouteBuilder.fingerprint(for: routeReplayPoints)
    }

    private var roadSnappingTaskKey: Int {
        RoadSnappedRouteBuilder.taskFingerprint(
            for: routeReplayPoints,
            isEnabled: snapTravelPathToRoads
        )
    }

    private var preparedRoadSnappedRoute: RoadSnappedRoute? {
        guard snapTravelPathToRoads,
              let roadSnappedRoute,
              roadSnappedRoute.sourceFingerprint == roadSnappingSourceFingerprint,
              roadSnappedRoute.sourcePointCount == routeReplayPoints.count else {
            return nil
        }

        return roadSnappedRoute
    }

    private var activeRoadSnappedRoute: RoadSnappedRoute? {
        guard let preparedRoadSnappedRoute,
              preparedRoadSnappedRoute.hasSnappedSegments else {
            return nil
        }

        return preparedRoadSnappedRoute
    }

    private var isPreparingRoadRoute: Bool {
        snapTravelPathToRoads && canReplayRoute && preparedRoadSnappedRoute == nil && !showStraightLinePathSegments
    }

    private var shouldDrawStraightLinePath: Bool {
        showStraightLinePathSegments || !snapTravelPathToRoads
    }

    private var usesMetricDistanceUnits: Bool {
        let key = "usesMetricDistanceUnits"
        if UserDefaults.standard.object(forKey: key) == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                if session.points.isEmpty {
                    noPointsSection
                } else {
                    mapSection
                }

                statsSection

                if let storedSession = session.storedSession {
                    editableDetailsSection(storedSession)
                } else {
                    inferredSection
                }

                visitsSection

                actionSection
            }
            .padding(.bottom, 28)
        }
        .background(TE.surface.ignoresSafeArea())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            nameText = session.storedSession?.displayName(defaultName: session.defaultTitle) ?? session.title
            notesText = session.storedSession?.notes ?? ""
            validateRouteReplayState()
        }
        .onDisappear {
            isRouteReplayPlaying = false
        }
        .onReceive(routeReplayTimer) { _ in
            advanceRouteReplayIfNeeded()
        }
        .task(id: roadSnappingTaskKey) {
            await refreshRoadSnappedRoute()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNameFieldFocused = false
                    isNotesFieldFocused = false
                    saveEditableDetails()
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(storeManager: storeManager)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "OUTING")

            TECard {
                TERow(showDivider: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(session.title.uppercased())
                                .font(TE.mono(.headline, weight: .bold))
                                .tracking(1.4)
                                .foregroundStyle(TE.textPrimary)
                                .lineLimit(2)

                            if session.isActive {
                                OutingBadge(text: "LIVE", color: TE.success)
                            } else if session.isInferred {
                                OutingBadge(text: "INFERRED", color: TE.warning)
                            }
                        }

                        Text(session.formattedTimeRange)
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var mapSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "PATH")

            SessionPathMapView(
                points: routeReplayPoints,
                replaySnapshot: isRouteReplayEnabled ? routeReplaySnapshot : nil,
                roadSnappedRoute: activeRoadSnappedRoute,
                showsStraightLineSegments: showStraightLinePathSegments,
                showsRawPathFallback: shouldDrawStraightLinePath
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(TE.border, lineWidth: 1)
            }
            .padding(.horizontal, 16)

            if isPreparingRoadRoute {
                routeSnappingStatus
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            if canReplayRoute {
                routeReplayControls
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
        }
    }

    private var routeSnappingStatus: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
                .tint(TE.accent)

            Text("MATCHING PATH TO ROADS…")
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(TE.textMuted)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(TE.textMuted.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var routeReplayControls: some View {
        if isRouteReplayEnabled, let routeReplaySnapshot {
            RouteReplayControl(
                snapshot: routeReplaySnapshot,
                pointCount: routeReplayPoints.count,
                progress: Binding(
                    get: { routeReplayProgress },
                    set: { routeReplayProgress = RouteReplayCalculator.clampedProgress($0) }
                ),
                isPlaying: isRouteReplayPlaying,
                onPlayPause: toggleRouteReplayPlayback,
                onScrub: { isRouteReplayPlaying = false },
                onClose: disableRouteReplay
            )
        } else {
            Button(action: startRouteReplay) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))

                    Text("PLAY OUTING")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(2)
                }
                .foregroundStyle(TE.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(TE.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(TE.accent.opacity(0.35), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(isPreparingRoadRoute)
            .opacity(isPreparingRoadRoute ? 0.55 : 1)
            .accessibilityHint(isPreparingRoadRoute
                ? "Wait for the outing path to be matched to roads."
                : "Opens route replay controls for this outing.")
        }
    }

    private var noPointsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "PATH")

            TECard {
                TERow(showDivider: false) {
                    HStack(spacing: 10) {
                        Image(systemName: "location.slash")
                            .foregroundStyle(TE.textMuted)
                        Text("No GPS points were saved for this outing yet.")
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var statsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "STATS")

            TECard {
                VStack(spacing: 0) {
                    detailRow(label: "START", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    detailRow(label: session.isActive ? "LATEST" : "END", value: session.effectiveEndDate.formatted(date: .abbreviated, time: .shortened))
                    detailRow(label: "DURATION", value: RecordingSessionFormatter.duration(session.duration))
                    detailRow(label: "DISTANCE", value: DistanceFormatter.format(meters: session.distanceMeters, usesMetric: usesMetricDistanceUnits))
                    detailRow(label: "POINTS", value: "\(session.pointCount)")
                    if session.outlierCount > 0 {
                        detailRow(label: "GPS GLITCHES", value: "\(session.outlierCount)")
                    }
                    if let averageSpeed = session.averageSpeedMetersPerSecond {
                        detailRow(label: "AVG SPEED", value: formattedSpeed(averageSpeed), showDivider: false)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func editableDetailsSection(_ storedSession: RecordingSession) -> some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DETAILS")

            TECard {
                VStack(spacing: 0) {
                    TERow {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NAME")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)

                            TextField("Outing name", text: $nameText)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .focused($isNameFieldFocused)
                                .onSubmit(saveEditableDetails)
                                .onChange(of: isNameFieldFocused) { _, focused in
                                    if !focused { saveEditableDetails() }
                                }
                        }
                    }

                    TERow(showDivider: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTES")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)

                            TextField("Add notes", text: $notesText, axis: .vertical)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                                .textFieldStyle(.plain)
                                .lineLimit(2...5)
                                .focused($isNotesFieldFocused)
                                .onChange(of: isNotesFieldFocused) { _, focused in
                                    if !focused { saveEditableDetails() }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: storedSession.isActive
                ? LocalizedStringKey("This outing is currently being recorded.")
                : LocalizedStringKey("Names and notes stay on-device with the recording session."))
        }
    }

    private var inferredSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DETAILS")

            TECard {
                TERow(showDivider: false) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(TE.warning)
                            .accessibilityHidden(true)

                        Text("This outing was auto-inferred from your GPS history using your inferred outing settings. New Shortcut start/stop recordings are saved exactly and can be named.")
                            .font(TE.mono(.caption2, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var visitsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VISITS")

            TECard {
                if visits.isEmpty {
                    TERow(showDivider: false) {
                        Text("No visits were detected during this outing.")
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                            TERow(showDivider: index != visits.count - 1) {
                                NavigationLink {
                                    VisitDetailView(visit: visit, viewModel: viewModel)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundStyle(viewModel.isCurrentVisit(visit) ? TE.accent : TE.danger)
                                            .accessibilityHidden(true)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(visit.displayName.uppercased())
                                                .font(TE.mono(.caption, weight: .semibold))
                                                .tracking(0.8)
                                                .foregroundStyle(TE.textPrimary)
                                                .lineLimit(1)

                                            Text("\(visit.formattedTimeRange) • \(visit.formattedDuration)")
                                                .font(TE.mono(.caption2, weight: .medium))
                                                .foregroundStyle(TE.textMuted)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(TE.textMuted.opacity(0.55))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIONS")

            TECard {
                TERow(showDivider: false) {
                    HStack(spacing: 12) {
                        Text("FORMAT")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)

                        Spacer()

                        Menu {
                            ForEach(ExportFormat.allCases, id: \.token) { format in
                                Button {
                                    outingDetailExportFormatToken = format.token
                                } label: {
                                    if outingExportFormat == format {
                                        Label(format.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(format.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(outingExportFormat.displayName.uppercased())
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.bold))
                            }
                            .font(TE.mono(.caption2, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(TE.accent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 10) {
                Button {
                    viewModel.focusMap(on: session)
                    onShowOnMap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.caption.weight(.bold))
                        Text("SHOW ON MAP")
                            .font(TE.mono(.caption, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(TE.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Button {
                    exportOuting()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: exportFolderManager.hasDefaultFolder && useDefaultExportFolder ? "square.and.arrow.down" : "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                        Text(exportButtonTitle)
                            .font(TE.mono(.caption, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(storeManager.isPurchased ? TE.accent : TE.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(storeManager.isPurchased ? TE.accent.opacity(0.08) : TE.textMuted.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(storeManager.isPurchased ? TE.accent.opacity(0.5) : TE.textMuted.opacity(0.25), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Exports this outing as a Markdown page with YAML properties.")
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)

            TESectionFooter(text: outingExportFooterText)
        }
    }

    private var outingExportFormat: ExportFormat {
        ExportFormat(exportKitFormatID: outingDetailExportFormatToken) ?? .markdown
    }

    private var exportButtonTitle: String {
        if !storeManager.isPurchased { return "UNLOCK EXPORT" }
        let formatName = outingExportFormat.displayName.uppercased()
        if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
            return "EXPORT \(formatName)"
        }
        return "SHARE \(formatName)"
    }

    private var outingExportFooterText: LocalizedStringKey {
        switch outingExportFormat {
        case .markdown:
            return "Markdown exports this outing as a page with YAML front matter, visits, and route points."
        case .json, .csv:
            return "This format exports an outing summary with timing, distance, visit count, notes, and coordinates."
        case .gpx, .kml, .geojson, .owntracks, .overland:
            return "This route format exports the outing's GPS route points. Notes and visit rows are not represented."
        }
    }

    private func detailRow(label: String, value: String, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack(spacing: 12) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textMuted)

                Spacer()

                Text(value)
                    .font(TE.mono(.caption, weight: .semibold))
                    .foregroundStyle(TE.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
        }
    }

    private func saveEditableDetails() {
        guard let storedSession = session.storedSession else { return }
        viewModel.updateRecordingSession(
            storedSession,
            customName: nameText,
            notes: notesText
        )
        nameText = storedSession.displayName(defaultName: session.defaultTitle)
        notesText = storedSession.notes ?? ""
    }

    private func exportOuting() {
        guard storeManager.isPurchased else {
            showingPaywall = true
            return
        }

        saveEditableDetails()

        var options = ExportOptions()
        options.dataKind = .outings
        options.format = outingExportFormat
        options.splitByDay = true

        do {
            if exportFolderManager.hasDefaultFolder && useDefaultExportFolder {
                let urls = try ExportService.saveOutingToDefaultFolder(
                    session,
                    visits: visits,
                    options: options,
                    filenamePattern: filenamePattern
                )
                ExportToastCenter.shared.show(.success(savedURLs: urls))
                AppReviewPromptCoordinator.shared.recordSuccessfulFileExport()
            } else {
                try ExportService.shareOuting(
                    session,
                    visits: visits,
                    options: options,
                    filenamePattern: filenamePattern,
                    completion: { completed in
                        guard completed else { return }
                        Task { @MainActor in
                            AppReviewPromptCoordinator.shared.recordSuccessfulFileExport()
                        }
                    }
                )
                ExportToastCenter.shared.show(.success(message: "Share sheet opened"))
            }
        } catch {
            viewModel.exportError = error.localizedDescription
            ExportToastCenter.shared.show(.failure(message: error.localizedDescription))
        }
    }

    private func startRouteReplay() {
        guard canReplayRoute else { return }
        if isPreparingRoadRoute { return }
        routeReplayProgress = 0
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
            isRouteReplayEnabled = true
        }
        isRouteReplayPlaying = true
    }

    private func disableRouteReplay() {
        isRouteReplayPlaying = false
        routeReplayProgress = 1
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
            isRouteReplayEnabled = false
        }
    }

    private func toggleRouteReplayPlayback() {
        guard canReplayRoute else {
            disableRouteReplay()
            return
        }

        if !isRouteReplayEnabled {
            startRouteReplay()
            return
        }

        if !isRouteReplayPlaying,
           let currentIndex = RouteReplayCalculator.index(for: routeReplayProgress, pointCount: routeReplayPoints.count),
           currentIndex >= routeReplayPoints.count - 1 {
            routeReplayProgress = 0
        }

        isRouteReplayPlaying.toggle()
    }

    private func advanceRouteReplayIfNeeded() {
        guard isRouteReplayEnabled, isRouteReplayPlaying else { return }
        guard canReplayRoute,
              let currentIndex = RouteReplayCalculator.index(for: routeReplayProgress, pointCount: routeReplayPoints.count) else {
            disableRouteReplay()
            return
        }

        let lastIndex = routeReplayPoints.count - 1
        let nextIndex = min(currentIndex + RouteReplayCalculator.playbackStepSize(pointCount: routeReplayPoints.count), lastIndex)
        routeReplayProgress = RouteReplayCalculator.progress(forIndex: nextIndex, pointCount: routeReplayPoints.count)

        if nextIndex >= lastIndex {
            isRouteReplayPlaying = false
        }
    }

    private func validateRouteReplayState() {
        routeReplayProgress = RouteReplayCalculator.clampedProgress(routeReplayProgress)

        guard canReplayRoute else {
            isRouteReplayPlaying = false
            isRouteReplayEnabled = false
            return
        }

        if isRouteReplayEnabled, routeReplaySnapshot == nil {
            routeReplayProgress = 0
        }
    }

    @MainActor
    private func refreshRoadSnappedRoute() async {
        guard snapTravelPathToRoads else {
            roadSnappedRoute = nil
            return
        }

        let sourcePoints = routeReplayPoints
        guard sourcePoints.count >= 2 else {
            roadSnappedRoute = nil
            return
        }

        let fingerprint = RoadSnappedRouteBuilder.fingerprint(for: sourcePoints)
        if roadSnappedRoute?.sourceFingerprint == fingerprint {
            return
        }

        let snapPoints = sourcePoints.map { RoadSnappingPoint(point: $0) }
        let route = await RoadSnappedRouteBuilder.buildRoute(
            for: snapPoints,
            sourceFingerprint: fingerprint
        )

        guard !Task.isCancelled else { return }
        roadSnappedRoute = route
    }

    private func formattedSpeed(_ metersPerSecond: Double) -> String {
        if usesMetricDistanceUnits {
            return String(format: "%.1f km/h", metersPerSecond * 3.6)
        }
        return String(format: "%.1f mph", metersPerSecond * 2.23693629)
    }
}

private struct OutingBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(TE.mono(.caption2, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(color.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct OutingStatChip: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(TE.accent)
                    .accessibilityHidden(true)

                Text(label)
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(TE.textMuted)
            }

            Text(value)
                .font(TE.mono(.caption2, weight: .bold))
                .foregroundStyle(TE.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(TE.textMuted.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    OutingsView(
        viewModel: LocationViewModel(
            modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self, RecordingSession.self).mainContext,
            locationManager: LocationManager()
        ),
        onShowOnMap: {}
    )
}
