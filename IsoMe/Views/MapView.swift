import SwiftUI
import MapKit
import SwiftData
import Combine

struct LocationMapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @State private var selectedVisit: Visit?
    @State private var selectedPointID: UUID?
    @State private var lastPointMarkerTap = Date.distantPast
    @State private var showingFilters = false
    @State private var showFilterBar = Self.initialFilterBarVisibility
    @State private var trackingPillExpanded = false
    @State private var showTravelPath = true
    @State private var showPointMarkers = true
    @State private var showStartEndMarkers = true
    @State private var showSessionPath = false
    @State private var showVisitMarkers = true
    @AppStorage("snapTravelPathToRoads") private var snapTravelPathToRoads = true
    @AppStorage("showStraightLinePathSegments") private var showStraightLinePathSegments = false
    @State private var roadSnappedRoute: RoadSnappedRoute?
    @State private var isRouteReplayEnabled = false
    @State private var isRouteReplayPlaying = false
    @State private var routeReplayProgress: Double = 1.0
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pendingSessionAutoFocus = false
    @State private var appliedMapFocusRequestID: UUID?
    @State private var activePreset: MapDatePreset? = .today
    @AppStorage("showOutliers") private var showOutliers = false
    @AppStorage("discordPromoDismissed") private var discordPromoDismissed = false

    init(viewModel: LocationViewModel) {
        self.viewModel = viewModel
        self.locationManager = viewModel.locationManager
    }

    private static var initialFilterBarVisibility: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--demo-open-map-filters")
        #else
        false
        #endif
    }

    private var isTracking: Bool {
        locationManager.isTrackingEnabled
    }

    // Minimum distance in meters between points to show as markers
    private let minimumPointDistance: Double = 50
    private let routeReplayTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var filteredVisits: [Visit] {
        viewModel.visitsInDateRange(viewModel.mapDateRange)
    }

    var filteredPoints: [LocationPoint] {
        let points = viewModel.mapLocationPoints
        return showOutliers ? points : points.filter { !$0.isOutlier }
    }

    var activeSessionPoints: [LocationPoint] {
        guard locationManager.isTrackingEnabled else { return [] }
        let points = viewModel.sessionMapLocationPoints
        return showOutliers ? points : points.filter { !$0.isOutlier }
    }

    var canReplayRoute: Bool {
        routeReplaySourcePoints.count >= 2
    }

    var routeReplaySourcePoints: [LocationPoint] {
        filteredPoints
    }

    private var roadSnappingSourceFingerprint: Int {
        RoadSnappedRouteBuilder.fingerprint(for: filteredPoints)
    }

    private var roadSnappingTaskKey: Int {
        RoadSnappedRouteBuilder.taskFingerprint(
            for: filteredPoints,
            isEnabled: snapTravelPathToRoads
        )
    }

    private var preparedRoadSnappedRoute: RoadSnappedRoute? {
        guard snapTravelPathToRoads,
              let roadSnappedRoute,
              roadSnappedRoute.sourceFingerprint == roadSnappingSourceFingerprint,
              roadSnappedRoute.sourcePointCount == filteredPoints.count else {
            return nil
        }

        return roadSnappedRoute
    }

    private var shouldDrawStraightLinePath: Bool {
        showStraightLinePathSegments || !snapTravelPathToRoads
    }

    var routeReplaySnapshot: RouteReplaySnapshot? {
        RouteReplayCalculator.snapshot(points: routeReplaySourcePoints, progress: routeReplayProgress)
    }

    var displayedTravelPathPoints: [LocationPoint] {
        if isRouteReplayEnabled, let routeReplaySnapshot {
            return routeReplaySnapshot.visiblePoints
        }
        return filteredPoints
    }

    private func displayedRoadSegments(
        from route: RoadSnappedRoute,
        upTo sourceIndex: Int? = nil
    ) -> [RoadSnappedRouteSegment] {
        let segments: [RoadSnappedRouteSegment]
        if let sourceIndex {
            segments = route.segments(upTo: sourceIndex)
        } else {
            segments = route.segments
        }

        guard !showStraightLinePathSegments else { return segments }
        return segments.filter(\.isSnapped)
    }
    
    var spacedPoints: [LocationPoint] {
        let pathPoints = displayedTravelPathPoints
        guard !pathPoints.isEmpty else { return [] }
        
        var result: [LocationPoint] = [pathPoints[0]]
        
        for point in pathPoints.dropFirst() {
            if let lastPoint = result.last {
                let distance = lastPoint.distance(to: point)
                if distance >= minimumPointDistance {
                    result.append(point)
                }
            }
        }
        
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, selection: $selectedVisit) {
                    // Current user location
                    UserAnnotation()

                    // Travel path from location points. In replay mode, keep the
                    // full route hidden and only draw the segment the playhead has reached.
                    // When road snapping is enabled, sparse GPS gaps are replaced with
                    // MapKit route polylines so the path follows roads instead of drawing
                    // abrupt straight chords between disconnected dots.
                    if isRouteReplayEnabled, let routeReplaySnapshot {
                        if let preparedRoadSnappedRoute {
                            ForEach(displayedRoadSegments(from: preparedRoadSnappedRoute, upTo: routeReplaySnapshot.index)) { segment in
                                MapPolyline(coordinates: segment.coordinates)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .blue.opacity(0.7), .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                    )
                            }
                        } else if shouldDrawStraightLinePath, routeReplaySnapshot.visiblePoints.count >= 2 {
                            let coordinates = routeReplaySnapshot.visiblePoints.map { $0.coordinate }
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .blue.opacity(0.7), .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                )
                        }
                    } else if showTravelPath && filteredPoints.count >= 2 {
                        if let preparedRoadSnappedRoute {
                            ForEach(displayedRoadSegments(from: preparedRoadSnappedRoute)) { segment in
                                MapPolyline(coordinates: segment.coordinates)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.3), .blue.opacity(0.7), .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                    )
                            }
                        } else if shouldDrawStraightLinePath {
                            let coordinates = filteredPoints.map { $0.coordinate }
                            MapPolyline(coordinates: coordinates)
                                .stroke(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .blue.opacity(0.7), .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                )
                        }
                    }

                    if isRouteReplayEnabled, let routeReplaySnapshot {
                        Annotation("Replay Position", coordinate: routeReplaySnapshot.currentPoint.coordinate) {
                            RouteReplayMarker(snapshot: routeReplaySnapshot)
                        }
                    }
                    
                    // Live session path (moved from Track tab)
                    if showSessionPath && activeSessionPoints.count >= 2 {
                        let sessionCoordinates = activeSessionPoints.map { $0.coordinate }
                        MapPolyline(coordinates: sessionCoordinates)
                            .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    
                    if showSessionPath, let firstSessionPoint = activeSessionPoints.first {
                        Annotation("Session Start", coordinate: firstSessionPoint.coordinate) {
                            StartMarker(
                                accessibilityLabel: "Active session start",
                                accessibilityValue: firstSessionPoint.accessibilityValue
                            )
                        }
                    }
                    
                    if showSessionPath,
                       let lastSessionPoint = activeSessionPoints.last,
                       activeSessionPoints.count > 1 {
                        Annotation("Current", coordinate: lastSessionPoint.coordinate) {
                            CurrentLocationMarker(
                                accessibilityLabel: "Active session current location",
                                accessibilityValue: lastSessionPoint.accessibilityValue
                            )
                        }
                    }
                    
                    // Start marker (oldest point in range)
                    if showStartEndMarkers, let firstPoint = filteredPoints.first {
                        Annotation("", coordinate: firstPoint.coordinate) {
                            PathStartMarker(timestamp: firstPoint.timestamp)
                        }
                    }
                    
                    // End marker (newest point in range, if different from start)
                    if showStartEndMarkers, 
                       let lastPoint = filteredPoints.last,
                       filteredPoints.count > 1 {
                        Annotation("", coordinate: lastPoint.coordinate) {
                            PathEndMarker(timestamp: lastPoint.timestamp)
                        }
                    }
                    
                    // Point markers (spaced apart)
                    if showPointMarkers {
                        ForEach(spacedPoints) { point in
                            Annotation("", coordinate: point.coordinate) {
                                PathPointMarker(
                                    point: point,
                                    isSelected: selectedPointID == point.id,
                                    onTap: { togglePointTooltip(for: point) }
                                )
                            }
                        }
                    }

                    // Visit markers
                    if showVisitMarkers {
                        ForEach(filteredVisits) { visit in
                            Annotation(
                                visit.displayName,
                                coordinate: visit.coordinate,
                                anchor: .bottom
                            ) {
                                VisitMarker(
                                    visit: visit,
                                    isSelected: selectedVisit?.id == visit.id,
                                    isCurrentVisit: viewModel.isCurrentVisit(visit)
                                )
                            }
                            .tag(visit)
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .simultaneousGesture(
                    TapGesture().onEnded(handleMapTap)
                )
                .accessibilityLabel("Location map")
                .accessibilityValue(mapAccessibilitySummary)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !discordPromoDismissed {
                        DiscordPromoBanner(onDismiss: dismissDiscordPromo)
                            .padding(.horizontal, 12)
                            .padding(.top, 6)
                            .padding(.bottom, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: discordPromoDismissed)

                // Bottom liquid-glass tracking + filter controls
                VStack(spacing: 8) {
                    Spacer()

                    if isRouteReplayEnabled, let routeReplaySnapshot {
                        RouteReplayControl(
                            snapshot: routeReplaySnapshot,
                            pointCount: routeReplaySourcePoints.count,
                            progress: Binding(
                                get: { routeReplayProgress },
                                set: { routeReplayProgress = RouteReplayCalculator.clampedProgress($0) }
                            ),
                            isPlaying: isRouteReplayPlaying,
                            onPlayPause: toggleRouteReplayPlayback,
                            onScrub: { isRouteReplayPlaying = false },
                            onClose: disableRouteReplay
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    MapTrackingControlPill(
                        viewModel: viewModel,
                        locationManager: locationManager,
                        isTracking: isTracking,
                        isExpanded: $trackingPillExpanded,
                        onPrimaryTap: handleTrackingTap
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    if isTracking,
                       let remaining = locationManager.remainingTime {
                        MapAutoOffPill(remaining: remaining)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    HStack(spacing: 8) {
                        if showFilterBar {
                            QuickFilterBar(
                                activePreset: activePreset,
                                showTravelPath: $showTravelPath,
                                showPointMarkers: $showPointMarkers,
                                showStartEndMarkers: $showStartEndMarkers,
                                showSessionPath: $showSessionPath,
                                showVisitMarkers: $showVisitMarkers,
                                snapTravelPathToRoads: $snapTravelPathToRoads,
                                showStraightLinePathSegments: $showStraightLinePathSegments,
                                isRouteReplayEnabled: isRouteReplayEnabled,
                                canReplayRoute: canReplayRoute,
                                hasSessionPoints: !activeSessionPoints.isEmpty,
                                onSelectPreset: { preset in
                                    activePreset = preset
                                    let range = preset.range()
                                    viewModel.mapDateRange = range
                                    viewModel.loadMapLocationPoints(in: range)
                                    validateRouteReplayState()
                                },
                                onSelectCustom: {
                                    showingFilters = true
                                },
                                onToggleRouteReplay: toggleRouteReplayMode,
                                onFitContent: { fitMapToContent() },
                                onFitSession: !activeSessionPoints.isEmpty ? { fitMapToSession() } : nil
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                        } else {
                            Spacer(minLength: 0)
                        }

                        FilterBarToggle(isOpen: showFilterBar) {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) {
                                showFilterBar.toggle()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: isTracking)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: isRouteReplayEnabled)
                .onChange(of: isTracking) { _, newValue in
                    if !newValue {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                            trackingPillExpanded = false
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingFilters) {
                DateRangeFilterSheet(
                    dateRange: $viewModel.mapDateRange,
                    isPresented: $showingFilters,
                    onApply: {
                        activePreset = nil
                        viewModel.loadMapLocationPoints(in: viewModel.mapDateRange)
                        validateRouteReplayState()
                    }
                )
            }
            .sheet(item: $selectedVisit) { visit in
                VisitQuickView(visit: visit, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                viewModel.loadAllVisits()
                if !applyMapFocusRequestIfNeeded() {
                    if let activePreset {
                        let range = activePreset.range()
                        viewModel.mapDateRange = range
                        viewModel.loadMapLocationPoints(in: range)
                    } else {
                        viewModel.loadMapLocationPoints(in: viewModel.mapDateRange)
                    }
                }

                validateRouteReplayState()

                if locationManager.isTrackingEnabled {
                    pendingSessionAutoFocus = true
                    attemptAutoFocusSession()
                }
            }
            .task(id: roadSnappingTaskKey) {
                await refreshRoadSnappedRoute()
            }
            .onReceive(routeReplayTimer) { _ in
                advanceRouteReplayIfNeeded()
            }
            .onChange(of: filteredPoints.count) { _, _ in
                validateRouteReplayState()
            }
            .onChange(of: showOutliers) { _, _ in
                validateRouteReplayState()
            }
            .onChange(of: viewModel.mapFocusRequest?.id) { _, _ in
                _ = applyMapFocusRequestIfNeeded()
            }
            .onChange(of: locationManager.isTrackingEnabled) { _, isEnabled in
                pendingSessionAutoFocus = isEnabled
                if isEnabled {
                    attemptAutoFocusSession()
                }
            }
            .onChange(of: activeSessionPoints.count) { _, _ in
                if pendingSessionAutoFocus {
                    attemptAutoFocusSession()
                }
            }
        }
    }

    @discardableResult
    private func applyMapFocusRequestIfNeeded() -> Bool {
        guard let request = viewModel.mapFocusRequest,
              appliedMapFocusRequestID != request.id else {
            return false
        }

        appliedMapFocusRequestID = request.id
        activePreset = nil
        viewModel.mapDateRange = request.range
        viewModel.loadMapLocationPoints(in: request.range)
        validateRouteReplayState()
        fitMapToContent()
        return true
    }

    private func fitMapToContent() {
        let coordinates = filteredVisits.map { $0.coordinate } + filteredPoints.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }

        let region = MKCoordinateRegion(coordinates: coordinates)
        cameraPosition = .region(region)
    }
    
    private func fitMapToSession() {
        guard !activeSessionPoints.isEmpty else { return }
        let coordinates = activeSessionPoints.map { $0.coordinate }
        let region = MKCoordinateRegion(coordinates: coordinates)
        cameraPosition = .region(region)
    }

    private func attemptAutoFocusSession() {
        guard pendingSessionAutoFocus, !activeSessionPoints.isEmpty else { return }
        fitMapToSession()
        pendingSessionAutoFocus = false
    }

    private func dismissDiscordPromo() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) {
            discordPromoDismissed = true
        }
    }

    private func togglePointTooltip(for point: LocationPoint) {
        lastPointMarkerTap = Date()
        withAnimation(reduceMotion ? nil : .spring(duration: 0.2)) {
            selectedPointID = selectedPointID == point.id ? nil : point.id
        }
    }

    private func handleMapTap() {
        // Map receives a tap alongside annotation buttons. Defer the check so a
        // point-marker tap can mark itself first, then only dismiss on true map taps.
        DispatchQueue.main.async {
            guard Date().timeIntervalSince(lastPointMarkerTap) > 0.15,
                  selectedPointID != nil else {
                return
            }

            withAnimation(reduceMotion ? nil : .spring(duration: 0.2)) {
                selectedPointID = nil
            }
        }
    }

    private func handleTrackingTap() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
            if isTracking {
                viewModel.stopTracking()
            } else {
                viewModel.startTracking()
            }
        }
    }

    private func toggleRouteReplayMode() {
        if isRouteReplayEnabled {
            disableRouteReplay()
        } else {
            guard canReplayRoute else { return }
            showTravelPath = true
            routeReplayProgress = 0
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                isRouteReplayEnabled = true
            }
        }
    }

    private func disableRouteReplay() {
        isRouteReplayPlaying = false
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
            toggleRouteReplayMode()
        }

        if !isRouteReplayPlaying,
           let currentIndex = RouteReplayCalculator.index(for: routeReplayProgress, pointCount: routeReplaySourcePoints.count),
           currentIndex >= routeReplaySourcePoints.count - 1 {
            routeReplayProgress = 0
        }

        isRouteReplayPlaying.toggle()
    }

    private func advanceRouteReplayIfNeeded() {
        guard isRouteReplayEnabled, isRouteReplayPlaying else { return }
        guard canReplayRoute,
              let currentIndex = RouteReplayCalculator.index(for: routeReplayProgress, pointCount: routeReplaySourcePoints.count) else {
            disableRouteReplay()
            return
        }

        let lastIndex = routeReplaySourcePoints.count - 1
        let nextIndex = min(currentIndex + RouteReplayCalculator.playbackStepSize(pointCount: routeReplaySourcePoints.count), lastIndex)
        routeReplayProgress = RouteReplayCalculator.progress(forIndex: nextIndex, pointCount: routeReplaySourcePoints.count)

        if nextIndex >= lastIndex {
            isRouteReplayPlaying = false
        }
    }

    private func validateRouteReplayState() {
        routeReplayProgress = RouteReplayCalculator.clampedProgress(routeReplayProgress)

        guard canReplayRoute else {
            if isRouteReplayEnabled {
                disableRouteReplay()
            } else {
                isRouteReplayPlaying = false
            }
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

        let sourcePoints = filteredPoints
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

    private var mapAccessibilitySummary: String {
        var parts: [String] = []
        parts.append("\(filteredVisits.count) \(filteredVisits.count == 1 ? "visit" : "visits")")
        if viewModel.mapLocationPointCount > filteredPoints.count {
            parts.append("Showing \(filteredPoints.count) of \(viewModel.mapLocationPointCount) path points")
        } else {
            parts.append("\(filteredPoints.count) \(filteredPoints.count == 1 ? "path point" : "path points")")
        }

        if isRouteReplayEnabled, let routeReplaySnapshot {
            parts.append("Route replay: \(routeReplaySnapshot.accessibilitySummary)")
        }

        if !activeSessionPoints.isEmpty {
            parts.append("Active session: \(viewModel.sessionAccessibilitySummary)")
        }

        return parts.joined(separator: ". ")
    }
}

// MARK: - Tracking Control Pills

struct MapTrackingControlPill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var viewModel: LocationViewModel
    @ObservedObject var locationManager: LocationManager
    let isTracking: Bool
    @Binding var isExpanded: Bool
    let onPrimaryTap: () -> Void

    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 10) {
            if isTracking {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) {
                        isExpanded.toggle()
                    }
                } label: {
                    statusBlock
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Session summary")
                .accessibilityValue(viewModel.sessionAccessibilitySummary)
                .accessibilityHint(isExpanded ? "Collapses session details." : "Expands session details.")
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                if isExpanded {
                    statsBlock
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Session details")
                        .accessibilityValue(viewModel.sessionAccessibilitySummary)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        ))
                }
            }

            primaryButton
        }
        .padding(.leading, isTracking ? 14 : 0)
        .padding(.trailing, isTracking ? 6 : 0)
        .padding(.vertical, isTracking ? 6 : 0)
        .background {
            if isTracking {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: isTracking)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
        .onAppear { pulseOpacity = reduceMotion ? 1.0 : 0.35 }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            pulseOpacity = shouldReduceMotion ? 1.0 : 0.35
        }
    }

    private var statusBlock: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isTracking ? TE.accent : TE.textMuted.opacity(0.35))
                .frame(width: 7, height: 7)
                .opacity(isTracking ? pulseOpacity : 1.0)
                .accessibilityHidden(true)
                .animation(
                    isTracking && !reduceMotion
                        ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        : nil,
                    value: pulseOpacity
                )

            if isTracking {
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    Text(viewModel.formattedSessionTrackingDuration)
                        .font(TE.mono(.subheadline, weight: .semibold))
                        .foregroundStyle(TE.textMuted)
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }
            } else {
                Text("STANDBY")
                    .font(TE.mono(.caption, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(TE.textMuted)
            }
        }
    }

    private var statsBlock: some View {
        HStack(spacing: 8) {
            Text(viewModel.formattedSessionDistance)
                .font(TE.mono(.caption, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .monospacedDigit()

            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 12)
                .accessibilityHidden(true)

            Text("\(viewModel.sessionLocationPoints.count) PTS")
                .font(TE.mono(.caption, weight: .medium))
                .foregroundStyle(TE.textMuted)
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimaryTap) {
            Image(systemName: isTracking ? "stop.fill" : "play.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(isTracking ? TE.danger : TE.accent)
                        .overlay {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .white.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(
                            color: (isTracking ? TE.danger : TE.accent).opacity(0.35),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isTracking ? "Stop tracking" : "Start tracking")
        .accessibilityValue(isTracking ? viewModel.sessionAccessibilitySummary : "Tracking is off.")
        .accessibilityHint(isTracking ? "Stops the active session." : "Starts a new location tracking session.")
        .sensoryFeedback(.impact(flexibility: .solid), trigger: isTracking)
    }
}

struct MapAutoOffPill: View {
    let remaining: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.caption2.weight(.medium))
                .foregroundStyle(TE.textMuted)
                .accessibilityHidden(true)

            Text("AUTO-OFF  \(formatTime(remaining))")
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(TE.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.45), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.6
                        )
                }
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tracking auto-off")
        .accessibilityValue("Stops in \(spokenTime(remaining)).")
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)H \(minutes)M" }
        return "\(minutes) MIN"
    }

    private func spokenTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours) \(hours == 1 ? "hour" : "hours") and \(minutes) \(minutes == 1 ? "minute" : "minutes")"
        }
        return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
    }
}

struct VisitMarker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let visit: Visit
    let isSelected: Bool
    let isCurrentVisit: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isCurrentVisit ? .blue : .red)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .accessibilityHidden(true)

                Image(systemName: "mappin")
                    .font(isSelected ? .title3 : .callout)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            Triangle()
                .fill(isCurrentVisit ? .blue : .red)
                .frame(width: 10, height: 8)
                .accessibilityHidden(true)
        }
        .frame(minWidth: 44, minHeight: 44)
        .animation(reduceMotion ? nil : .spring(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCurrentVisit ? "Current visit at \(visit.displayName)" : "Visit at \(visit.displayName)")
        .accessibilityValue(visit.accessibilityValue)
        .accessibilityHint(visit.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Path Point Markers

struct MapAnnotationTooltipOverlay<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 6) {
            content

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .fixedSize(horizontal: true, vertical: true)
        .allowsHitTesting(false)
        .transition(.scale.combined(with: .opacity))
    }
}

struct PathPointMarker: View {
    let point: LocationPoint
    let isSelected: Bool
    let onTap: () -> Void

    private var markerColor: Color {
        if isSelected { return TE.lcdGreen }
        return point.isOutlier ? .orange : .blue
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(markerColor.opacity(0.18))
                        .frame(width: 24, height: 24)

                    Circle()
                        .stroke(.white.opacity(0.9), lineWidth: 2)
                        .frame(width: 16, height: 16)
                }

                Circle()
                    .fill(markerColor)
                    .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
                    .overlay {
                        Circle()
                            .stroke(.white, lineWidth: isSelected ? 2 : 1.5)
                    }
            }
            .shadow(color: markerColor.opacity(isSelected ? 0.55 : 0.35), radius: isSelected ? 6 : 3, y: 1)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if isSelected {
                MapAnnotationTooltipOverlay {
                    PathPointTooltip(point: point)
                }
            }
        }
        .accessibilityLabel(point.isOutlier ? "Outlier path point" : "Path point")
        .accessibilityValue(point.accessibilityValue)
        .accessibilityHint(isSelected ? "Hides point metadata." : "Shows point metadata.")
    }
}

struct PathPointTooltip: View {
    @AppStorage("usesMetricDistanceUnits") private var usesMetricDistanceUnits = true
    let point: LocationPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("POINT")
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(TE.textMuted)

                Spacer(minLength: 4)

                Text(point.timestamp.formatted(date: .abbreviated, time: .standard))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }

            Divider()
                .overlay(Color.primary.opacity(0.12))

            PathPointTooltipRow(label: "COORDS", value: coordinateText)
            PathPointTooltipRow(label: "ACCURACY", value: "±\(formatDistance(point.horizontalAccuracy))")

            if let altitude = point.altitude {
                PathPointTooltipRow(label: "ALTITUDE", value: formatDistance(altitude))
            }

            if let speed = point.speed {
                PathPointTooltipRow(label: "SPEED", value: formattedSpeed(speed))
            }

            if point.isOutlier {
                PathPointTooltipRow(label: "STATUS", value: "GPS outlier")
            }
        }
        .padding(10)
        .frame(width: 240, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                }
        }
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .transition(.scale.combined(with: .opacity))
        .accessibilityHidden(true)
    }

    private var coordinateText: String {
        String(format: "%.5f, %.5f", point.latitude, point.longitude)
    }

    private func formatDistance(_ meters: Double) -> String {
        DistanceFormatter.format(meters: meters, usesMetric: usesMetricDistanceUnits)
    }

    private func formattedSpeed(_ metersPerSecond: Double) -> String {
        if usesMetricDistanceUnits {
            return String(format: "%.1f km/h", metersPerSecond * 3.6)
        }
        return String(format: "%.1f mph", metersPerSecond * 2.23693629)
    }
}

struct PathPointTooltipRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(TE.mono(.caption2, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(TE.textMuted)
                .frame(width: 62, alignment: .leading)

            Text(value)
                .font(TE.mono(.caption2, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Path Start/End Markers

struct PathStartMarker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let timestamp: Date
    @State private var showingTooltip = false
    
    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.2)) {
                showingTooltip.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                Image(systemName: "flag.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .shadow(color: .green.opacity(0.4), radius: 4, y: 2)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showingTooltip {
                MapAnnotationTooltipOverlay {
                    PathEndpointTooltip(label: "START", timestamp: timestamp)
                }
            }
        }
        .accessibilityLabel("Path start")
        .accessibilityValue(timestamp.formatted(date: .abbreviated, time: .shortened))
        .accessibilityHint(showingTooltip ? "Hides the start time." : "Shows the start time.")
    }
}

struct PathEndpointTooltip: View {
    let label: String
    let timestamp: Date

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(TE.textMuted)

            Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .transition(.scale.combined(with: .opacity))
        .accessibilityHidden(true)
    }
}

struct PathEndMarker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let timestamp: Date
    @State private var showingTooltip = false
    
    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.2)) {
                showingTooltip.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                Image(systemName: "flag.checkered")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .shadow(color: .red.opacity(0.4), radius: 4, y: 2)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showingTooltip {
                MapAnnotationTooltipOverlay {
                    PathEndpointTooltip(label: "END", timestamp: timestamp)
                }
            }
        }
        .accessibilityLabel("Path end")
        .accessibilityValue(timestamp.formatted(date: .abbreviated, time: .shortened))
        .accessibilityHint(showingTooltip ? "Hides the end time." : "Shows the end time.")
    }
}

struct RouteReplayMarker: View {
    let snapshot: RouteReplaySnapshot

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 34, height: 34)
                .shadow(color: TE.accent.opacity(0.35), radius: 8, y: 3)
                .accessibilityHidden(true)

            Circle()
                .fill(TE.accent)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Image(systemName: "play.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .offset(x: 1)
                .accessibilityHidden(true)
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route replay position")
        .accessibilityValue(snapshot.accessibilitySummary)
    }
}

struct RouteReplayControl: View {
    @AppStorage("usesMetricDistanceUnits") private var usesMetricDistanceUnits = true
    let snapshot: RouteReplaySnapshot
    let pointCount: Int
    @Binding var progress: Double
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onScrub: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(TE.accent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause route replay" : "Play route replay")

                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUTE REPLAY")
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(TE.textMuted)

                    Text(snapshot.currentPoint.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("\(snapshot.index + 1)/\(pointCount) PTS")
                    .font(TE.mono(.caption2, weight: .semibold))
                    .foregroundStyle(TE.textMuted)
                    .monospacedDigit()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close route replay")
            }

            Slider(
                value: Binding(
                    get: { progress },
                    set: { newValue in
                        progress = RouteReplayCalculator.clampedProgress(newValue)
                        onScrub()
                    }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if editing { onScrub() }
                }
            ) {
                Text("Route replay progress")
            }
            .tint(TE.accent)
            .accessibilityValue(snapshot.accessibilitySummary)

            HStack(spacing: 8) {
                RouteReplayStat(label: "ELAPSED", value: formatDuration(snapshot.elapsedDuration))
                RouteReplayStat(label: "DURATION", value: formatDuration(snapshot.totalDuration))
                RouteReplayStat(label: "DISTANCE", value: formattedDistanceProgress)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        }
        .accessibilityElement(children: .contain)
    }

    private var formattedDistanceProgress: String {
        let current = DistanceFormatter.format(meters: snapshot.distanceMeters, usesMetric: usesMetricDistanceUnits)
        let total = DistanceFormatter.format(meters: snapshot.totalDistanceMeters, usesMetric: usesMetricDistanceUnits)
        return "\(current) / \(total)"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct RouteReplayStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(TE.textMuted)

            Text(value)
                .font(TE.mono(.caption, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
    }
}

struct DateRangeChip: View {
    let range: ClosedRange<Date>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(formattedRange)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var formattedRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        let start = formatter.string(from: range.lowerBound)
        let end = formatter.string(from: range.upperBound)

        if start == end {
            return start
        }
        return "\(start) - \(end)"
    }
}

struct DateRangeFilterSheet: View {
    @Binding var dateRange: ClosedRange<Date>
    @Binding var isPresented: Bool
    var onApply: (() -> Void)? = nil

    @State private var startDate: Date
    @State private var endDate: Date

    init(
        dateRange: Binding<ClosedRange<Date>>,
        isPresented: Binding<Bool>,
        onApply: (() -> Void)? = nil
    ) {
        _dateRange = dateRange
        _isPresented = isPresented
        self.onApply = onApply
        _startDate = State(initialValue: dateRange.wrappedValue.lowerBound)
        _endDate = State(initialValue: dateRange.wrappedValue.upperBound)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quick Select") {
                    Button("Today") {
                        let today = Calendar.current.startOfDay(for: Date())
                        startDate = today
                        endDate = Date()
                    }

                    Button("Yesterday") {
                        let calendar = Calendar.current
                        let startOfToday = calendar.startOfDay(for: Date())
                        startDate = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
                        endDate = Date(timeIntervalSinceReferenceDate: startOfToday.timeIntervalSinceReferenceDate.nextDown)
                    }

                    Button("Last 7 Days") {
                        endDate = Date()
                        startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
                    }

                    Button("Last 30 Days") {
                        endDate = Date()
                        startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
                    }

                    Button("All Time") {
                        startDate = Date.distantPast
                        endDate = Date()
                    }
                }

                Section("Custom Range") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dateRange = startDate...endDate
                        onApply?()
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct VisitQuickView: View {
    @Bindable var visit: Visit
    @Bindable var viewModel: LocationViewModel
    @State private var nameText: String = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField("Visit name", text: $nameText)
                                    .font(.title2.weight(.semibold))
                                    .textFieldStyle(.plain)
                                    .submitLabel(.done)
                                    .focused($isNameFieldFocused)
                                    .onSubmit(saveName)
                                    .onChange(of: isNameFieldFocused) { _, focused in
                                        if !focused {
                                            saveName()
                                        }
                                    }
                            }

                            Spacer()

                            if visit.hasCustomName {
                                Button("Reset") {
                                    resetName()
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityHint("Restores the automatically detected visit name.")
                            }

                            if viewModel.isCurrentVisit(visit) {
                                Text("Now")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }

                        if visit.hasCustomName, visit.automaticDisplayName != visit.displayName {
                            Text("Detected as \(visit.automaticDisplayName)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        if let address = visit.address, !address.isEmpty, address != visit.displayName {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        NearbyVisitNameSuggestionSection(visit: visit) { suggestion in
                            applyNameSuggestion(suggestion)
                        }
                    }

                    Divider()

                    // Time info
                    HStack(spacing: 24) {
                        VStack(alignment: .leading) {
                            Text("Arrived")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(visit.arrivedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                        }

                        if let departed = visit.departedAt {
                            VStack(alignment: .leading) {
                                Text("Departed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(departed.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Duration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(visit.formattedDuration)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    if let notes = visit.notes, !notes.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notes)
                                .font(.subheadline)
                        }
                    }

                    NavigationLink {
                        VisitDetailView(visit: visit, viewModel: viewModel)
                    } label: {
                        Label("More Details", systemImage: "info.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                nameText = visit.displayName
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isNameFieldFocused = false
                        saveName()
                    }
                }
            }
        }
    }

    private func saveName() {
        viewModel.updateVisitName(visit, customName: nameText)
        nameText = visit.displayName
    }

    private func resetName() {
        viewModel.clearVisitName(visit)
        nameText = visit.displayName
    }

    private func applyNameSuggestion(_ suggestion: NearbyPlaceSuggestion) {
        isNameFieldFocused = false
        nameText = suggestion.name
        saveName()
    }
}

// MARK: - Quick Filter Bar

enum MapDatePreset: CaseIterable, Hashable {
    case today, yesterday, sevenDays, thirtyDays, all

    var label: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .all: return "All"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .sevenDays: return "Last 7 days"
        case .thirtyDays: return "Last 30 days"
        case .all: return "All time"
        }
    }

    func range(referenceDate: Date = Date()) -> ClosedRange<Date> {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: referenceDate)...referenceDate
        case .yesterday:
            let startOfToday = calendar.startOfDay(for: referenceDate)
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            let endOfYesterday = Date(timeIntervalSinceReferenceDate: startOfToday.timeIntervalSinceReferenceDate.nextDown)
            return startOfYesterday...endOfYesterday
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: referenceDate)!...referenceDate
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: referenceDate)!...referenceDate
        case .all:
            return Date.distantPast...referenceDate
        }
    }
}

struct FilterBarToggle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOpen ? "xmark" : "slider.horizontal.3")
                .font(.body.weight(.semibold))
                .foregroundStyle(isOpen ? Color.white : Color.primary.opacity(0.75))
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(isOpen ? AnyShapeStyle(TE.accent) : AnyShapeStyle(.ultraThinMaterial))
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
                }
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Close map filters" : "Open map filters")
        .accessibilityHint(isOpen ? "Hides date, layer, and fit controls." : "Shows date, layer, and fit controls.")
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isOpen)
    }
}

struct QuickFilterBar: View {
    let activePreset: MapDatePreset?
    @Binding var showTravelPath: Bool
    @Binding var showPointMarkers: Bool
    @Binding var showStartEndMarkers: Bool
    @Binding var showSessionPath: Bool
    @Binding var showVisitMarkers: Bool
    @Binding var snapTravelPathToRoads: Bool
    @Binding var showStraightLinePathSegments: Bool
    let isRouteReplayEnabled: Bool
    let canReplayRoute: Bool
    let hasSessionPoints: Bool
    let onSelectPreset: (MapDatePreset) -> Void
    let onSelectCustom: () -> Void
    let onToggleRouteReplay: () -> Void
    let onFitContent: () -> Void
    let onFitSession: (() -> Void)?
    @State private var activeLayerHelp: LayerToggleHelp?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--seed-screenshot-data") {
                    LayerToggleButton(
                        systemImage: "road.lanes",
                        label: "Road-matched path",
                        help: .roadMatchedPath,
                        isOn: $snapTravelPathToRoads,
                        activeHelp: $activeLayerHelp
                    )
                    LayerToggleButton(
                        systemImage: "line.diagonal",
                        label: "Straight-line path gaps",
                        help: .straightLinePathGaps,
                        isOn: $showStraightLinePathSegments,
                        activeHelp: $activeLayerHelp
                    )
                    PillSeparator()
                }
                #endif

                ForEach(MapDatePreset.allCases, id: \.self) { preset in
                    PresetPill(
                        label: preset.label,
                        accessibilityLabel: preset.accessibilityLabel,
                        isActive: activePreset == preset
                    ) {
                        onSelectPreset(preset)
                    }
                }

                PresetPill(
                    label: "Custom",
                    icon: "calendar",
                    accessibilityLabel: "Custom date range",
                    isActive: activePreset == nil
                ) {
                    onSelectCustom()
                }

                PillSeparator()

                LayerToggleButton(
                    systemImage: "mappin.circle.fill",
                    label: "Visit markers",
                    help: .visitMarkers,
                    isOn: $showVisitMarkers,
                    activeHelp: $activeLayerHelp
                )
                LayerToggleButton(
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    label: "Travel path",
                    help: .travelPath,
                    isOn: $showTravelPath,
                    activeHelp: $activeLayerHelp
                )
                LayerToggleButton(
                    systemImage: "road.lanes",
                    label: "Road-matched path",
                    help: .roadMatchedPath,
                    isOn: $snapTravelPathToRoads,
                    activeHelp: $activeLayerHelp
                )
                LayerToggleButton(
                    systemImage: "line.diagonal",
                    label: "Straight-line path gaps",
                    help: .straightLinePathGaps,
                    isOn: $showStraightLinePathSegments,
                    activeHelp: $activeLayerHelp
                )
                LayerToggleButton(
                    systemImage: "smallcircle.filled.circle",
                    label: "Point markers",
                    help: .pointMarkers,
                    isOn: $showPointMarkers,
                    activeHelp: $activeLayerHelp
                )
                LayerToggleButton(
                    systemImage: "flag.fill",
                    label: "Start and end markers",
                    help: .startEndMarkers,
                    isOn: $showStartEndMarkers,
                    activeHelp: $activeLayerHelp
                )
                if hasSessionPoints {
                    LayerToggleButton(
                        systemImage: "waveform.path.ecg",
                        label: "Active session path",
                        help: .activeSessionPath,
                        isOn: $showSessionPath,
                        activeHelp: $activeLayerHelp
                    )
                }

                RouteReplayToggleButton(
                    isOn: isRouteReplayEnabled,
                    isEnabled: canReplayRoute,
                    action: onToggleRouteReplay
                )

                PillSeparator()

                FitMenuButton(
                    onFitContent: onFitContent,
                    onFitSession: onFitSession
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("--demo-road-layer-help") {
                LayerToggleHelpPopover(systemImage: "road.lanes", help: .roadMatchedPath, isOn: snapTravelPathToRoads)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
                    .offset(x: 0, y: -190)
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--demo-road-layer-help") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    activeLayerHelp = .roadMatchedPath
                }
            }
        }
        #endif
    }
}

struct PresetPill: View {
    let label: String
    var icon: String? = nil
    var accessibilityLabel: String? = nil
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.medium))
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(isActive ? TE.accent : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityValue(isActive ? "Selected" : "Not selected")
        .accessibilityHint("Filters the map date range.")
    }
}

struct LayerToggleHelp: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String

    static let visitMarkers = LayerToggleHelp(
        id: "visit-markers",
        title: "Visit markers",
        message: "Shows places iso.me detected as stops in the selected date range. Hide them when you want an uncluttered route-only map."
    )

    static let travelPath = LayerToggleHelp(
        id: "travel-path",
        title: "Travel path",
        message: "Draws your GPS trail for the selected date range. Turn it off to focus on visits, pins, or the live session."
    )

    static let roadMatchedPath = LayerToggleHelp(
        id: "road-matched-path",
        title: "Road-matched path",
        message: "Uses Apple Maps routes to bend sparse GPS gaps onto nearby roads when possible, instead of drawing rough point-to-point lines."
    )

    static let straightLinePathGaps = LayerToggleHelp(
        id: "straight-line-path-gaps",
        title: "Straight-line path gaps",
        message: "Reveals fallback straight segments wherever road matching has no confident route. Useful when you want to inspect raw gaps."
    )

    static let pointMarkers = LayerToggleHelp(
        id: "point-markers",
        title: "Point markers",
        message: "Shows sampled GPS dots along the path. Tap a dot to inspect its timestamp, coordinates, and accuracy."
    )

    static let startEndMarkers = LayerToggleHelp(
        id: "start-end-markers",
        title: "Start and end markers",
        message: "Marks the first and latest recorded points in the current date range so you can see where the route begins and ends."
    )

    static let activeSessionPath = LayerToggleHelp(
        id: "active-session-path",
        title: "Active session path",
        message: "Overlays the route for the tracking session that is currently running, separate from the historical date-range path."
    )
}

struct LayerToggleButtonLabel: View {
    let systemImage: String
    let isOn: Bool

    private var iconColor: Color {
        isOn ? Color.white : Color.primary.opacity(0.55)
    }

    private var fillColor: Color {
        isOn ? TE.accent : Color.clear
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(width: 44, height: 44)
            .foregroundStyle(iconColor)
            .background(Circle().fill(fillColor))
    }
}

struct LayerToggleButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let label: String
    let help: LayerToggleHelp
    @Binding var isOn: Bool
    @Binding var activeHelp: LayerToggleHelp?

    private var isShowingHelp: Binding<Bool> {
        Binding(
            get: { activeHelp?.id == help.id },
            set: { isPresented in
                guard !isPresented, activeHelp?.id == help.id else { return }
                activeHelp = nil
            }
        )
    }

    var body: some View {
        buttonContent
            .popover(isPresented: isShowingHelp) {
                popoverContent
            }
            .sensoryFeedback(.selection, trigger: activeHelp?.id == help.id)
    }

    private var buttonContent: some View {
        LayerToggleButtonLabel(systemImage: systemImage, isOn: isOn)
            .contentShape(Circle())
            .gesture(layerGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "Shown" : "Hidden")
            .accessibilityHint("Double-tap to toggle this map layer. Touch and hold for an explanation.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                toggleLayer()
            }
            .accessibilityAction(named: Text("Show Explanation")) {
                activeHelp = help
            }
    }

    private var popoverContent: some View {
        LayerToggleHelpPopover(systemImage: systemImage, help: help, isOn: isOn)
            .presentationCompactAdaptation(.popover)
    }

    private var layerGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first(_):
                    activeHelp = help
                case .second(_):
                    toggleLayer()
                }
            }
    }

    private func toggleLayer() {
        activeHelp = nil
        withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
            isOn.toggle()
        }
    }
}

struct LayerToggleHelpPopover: View {
    let systemImage: String
    let help: LayerToggleHelp
    let isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background {
                        Circle().fill(isOn ? TE.accent : TE.textMuted.opacity(0.55))
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(help.title)
                        .font(TE.mono(.subheadline, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(isOn ? "CURRENTLY SHOWN" : "CURRENTLY HIDDEN")
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(isOn ? TE.accent : TE.textMuted)
                }
            }

            Text(help.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 260, alignment: .leading)
        .padding(14)
    }
}

struct RouteReplayToggleButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
                action()
            }
        } label: {
            Image(systemName: isOn ? "pause.rectangle.fill" : "play.rectangle")
                .font(.subheadline.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(foregroundStyle)
                .background {
                    Circle()
                        .fill(isOn ? TE.accent : Color.clear)
                }
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled && !isOn)
        .accessibilityLabel(isOn ? "Close route replay" : "Open route replay")
        .accessibilityValue(isEnabled ? (isOn ? "Replay controls are open" : "Available") : "Unavailable")
        .accessibilityHint(isEnabled ? "Shows controls for scrubbing and replaying the visible route." : "Select a date range with at least two path points.")
    }

    private var foregroundStyle: Color {
        if isOn { return .white }
        return isEnabled ? Color.primary.opacity(0.7) : Color.primary.opacity(0.25)
    }
}

struct PillSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}

struct FitMenuButton: View {
    let onFitContent: () -> Void
    let onFitSession: (() -> Void)?

    var body: some View {
        Menu {
            if let onFitSession {
                Button {
                    onFitSession()
                } label: {
                    Label("Fit Active Session", systemImage: "location.north.line")
                }
            }
            Button {
                onFitContent()
            } label: {
                Label("Fit All Visits", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        } label: {
            Image(systemName: "scope")
                .font(.subheadline.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Color.primary.opacity(0.7))
        }
        .accessibilityLabel("Fit map")
        .accessibilityHint("Shows options for zooming the map to available content.")
    }
}

// MARK: - Route Replay Helpers

struct RouteReplaySnapshot {
    let index: Int
    let progress: Double
    let totalPointCount: Int
    let visiblePoints: [LocationPoint]
    let currentPoint: LocationPoint
    let elapsedDuration: TimeInterval
    let totalDuration: TimeInterval
    let distanceMeters: Double
    let totalDistanceMeters: Double

    var accessibilitySummary: String {
        let elapsed = RouteReplayCalculator.formattedDuration(elapsedDuration)
        let duration = RouteReplayCalculator.formattedDuration(totalDuration)
        let distance = DistanceFormatter.format(meters: distanceMeters, usesMetric: true)
        let totalDistance = DistanceFormatter.format(meters: totalDistanceMeters, usesMetric: true)
        return "Point \(index + 1) of \(totalPointCount). Time \(currentPoint.accessibilityTimestamp). Elapsed \(elapsed) of \(duration). Distance \(distance) of \(totalDistance)."
    }
}

enum RouteReplayCalculator {
    static func clampedProgress(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(1, max(0, progress))
    }

    static func index(for progress: Double, pointCount: Int) -> Int? {
        guard pointCount > 0 else { return nil }
        guard pointCount > 1 else { return 0 }
        let lastIndex = pointCount - 1
        let scaled = clampedProgress(progress) * Double(lastIndex)
        return min(lastIndex, max(0, Int(scaled.rounded())))
    }

    static func progress(forIndex index: Int, pointCount: Int) -> Double {
        guard pointCount > 1 else { return 0 }
        let lastIndex = pointCount - 1
        let clampedIndex = min(lastIndex, max(0, index))
        return Double(clampedIndex) / Double(lastIndex)
    }

    static func playbackStepSize(pointCount: Int) -> Int {
        guard pointCount > 1 else { return 1 }
        // Keep long, downsampled routes from taking several minutes while still
        // advancing smoothly for short paths.
        let targetTicks = 180.0
        return max(1, Int(ceil(Double(pointCount - 1) / targetTicks)))
    }

    static func snapshot(points: [LocationPoint], progress: Double) -> RouteReplaySnapshot? {
        guard points.count >= 2, let index = index(for: progress, pointCount: points.count) else {
            return nil
        }

        let visiblePoints = Array(points.prefix(index + 1))
        let currentPoint = points[index]
        let firstTimestamp = points.first?.timestamp ?? currentPoint.timestamp
        let lastTimestamp = points.last?.timestamp ?? currentPoint.timestamp

        return RouteReplaySnapshot(
            index: index,
            progress: clampedProgress(progress),
            totalPointCount: points.count,
            visiblePoints: visiblePoints,
            currentPoint: currentPoint,
            elapsedDuration: currentPoint.timestamp.timeIntervalSince(firstTimestamp),
            totalDuration: lastTimestamp.timeIntervalSince(firstTimestamp),
            distanceMeters: totalDistance(in: visiblePoints),
            totalDistanceMeters: totalDistance(in: points)
        )
    }

    static func totalDistance(in points: [LocationPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total: Double = 0
        for index in 1..<points.count {
            total += points[index - 1].distance(to: points[index])
        }
        return total
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Road Snapping Helpers

struct RoadSnappingPoint: @unchecked Sendable {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let speed: Double?
    let horizontalAccuracy: Double

    init(
        coordinate: CLLocationCoordinate2D,
        timestamp: Date,
        speed: Double? = nil,
        horizontalAccuracy: Double
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }

    init(point: LocationPoint) {
        self.init(
            coordinate: point.coordinate,
            timestamp: point.timestamp,
            speed: point.speed,
            horizontalAccuracy: point.horizontalAccuracy
        )
    }
}

extension RoadSnappingPoint {
    init(_ point: LocationPoint) {
        self.init(point: point)
    }
}

struct RoadSnappedRouteSegment: Identifiable, @unchecked Sendable {
    let id: String
    let startIndex: Int
    let endIndex: Int
    let coordinates: [CLLocationCoordinate2D]
    let isSnapped: Bool

    init(
        startIndex: Int,
        endIndex: Int,
        coordinates: [CLLocationCoordinate2D],
        isSnapped: Bool
    ) {
        self.id = "\(startIndex)-\(endIndex)-\(isSnapped ? "snapped" : "raw")"
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.coordinates = coordinates
        self.isSnapped = isSnapped
    }

    func mergingRaw(
        endIndex newEndIndex: Int,
        coordinates newCoordinates: [CLLocationCoordinate2D]
    ) -> RoadSnappedRouteSegment {
        var mergedCoordinates = coordinates
        if newCoordinates.count > 1 {
            mergedCoordinates.append(contentsOf: newCoordinates.dropFirst())
        }

        return RoadSnappedRouteSegment(
            startIndex: startIndex,
            endIndex: newEndIndex,
            coordinates: mergedCoordinates,
            isSnapped: false
        )
    }

    func clipped(toEndIndex requestedEndIndex: Int) -> RoadSnappedRouteSegment? {
        guard !isSnapped else { return nil }
        let clippedEndIndex = min(endIndex, max(startIndex, requestedEndIndex))
        guard clippedEndIndex > startIndex else { return nil }

        let coordinateCount = clippedEndIndex - startIndex + 1
        guard coordinates.count >= coordinateCount else { return nil }

        return RoadSnappedRouteSegment(
            startIndex: startIndex,
            endIndex: clippedEndIndex,
            coordinates: Array(coordinates.prefix(coordinateCount)),
            isSnapped: false
        )
    }
}

struct RoadSnappedRoute: @unchecked Sendable {
    let sourceFingerprint: Int
    let sourcePointCount: Int
    let segments: [RoadSnappedRouteSegment]

    var hasSnappedSegments: Bool {
        segments.contains { $0.isSnapped }
    }

    func segments(upTo sourceIndex: Int) -> [RoadSnappedRouteSegment] {
        guard sourceIndex > 0 else { return [] }

        var visibleSegments: [RoadSnappedRouteSegment] = []
        for segment in segments {
            if segment.endIndex <= sourceIndex {
                visibleSegments.append(segment)
                continue
            }

            if segment.startIndex < sourceIndex,
               let clipped = segment.clipped(toEndIndex: sourceIndex) {
                visibleSegments.append(clipped)
            }
            break
        }

        return visibleSegments
    }
}

enum RoadSnappedRouteBuilder {
    private static let minimumSnapDistance: CLLocationDistance = 120
    private static let maximumSnapDistance: CLLocationDistance = 25_000
    private static let maximumSnapTimeGap: TimeInterval = 2 * 60 * 60
    private static let maximumSnapSpeed: CLLocationSpeed = 55
    private static let walkingSpeedThreshold: CLLocationSpeed = 3.2
    private static let maximumDirectionsRequests = 40
    private static let duplicateCoordinateThreshold: CLLocationDistance = 2

    static func fingerprint(for points: [LocationPoint]) -> Int {
        var hasher = Hasher()
        hasher.combine(points.count)

        for point in points {
            hasher.combine(point.id)
            hasher.combine(point.latitude)
            hasher.combine(point.longitude)
            hasher.combine(point.timestamp)
            hasher.combine(point.isOutlier)
        }

        return hasher.finalize()
    }

    static func taskFingerprint(for points: [LocationPoint], isEnabled: Bool) -> Int {
        var hasher = Hasher()
        hasher.combine(isEnabled)
        hasher.combine(fingerprint(for: points))
        return hasher.finalize()
    }

    static func buildRoute(
        for points: [RoadSnappingPoint],
        sourceFingerprint: Int
    ) async -> RoadSnappedRoute {
        guard points.count >= 2 else {
            return RoadSnappedRoute(
                sourceFingerprint: sourceFingerprint,
                sourcePointCount: points.count,
                segments: []
            )
        }

        let candidates = zip(points.indices, points.dropFirst()).compactMap { index, endPoint -> CandidateSegment? in
            let startPoint = points[index]
            let endIndex = index + 1
            guard startPoint.coordinate.isValidRoadSnapCoordinate,
                  endPoint.coordinate.isValidRoadSnapCoordinate else {
                return nil
            }

            return CandidateSegment(
                startIndex: index,
                endIndex: endIndex,
                start: startPoint,
                end: endPoint
            )
        }

        let snapIndexes = Set(
            candidates
                .filter(shouldAttemptRoadSnap)
                .sorted { $0.distance > $1.distance }
                .prefix(maximumDirectionsRequests)
                .map(\.startIndex)
        )

        var routeSegments: [RoadSnappedRouteSegment] = []
        routeSegments.reserveCapacity(candidates.count)

        for candidate in candidates {
            if Task.isCancelled { break }

            if snapIndexes.contains(candidate.startIndex),
               let coordinates = await snappedCoordinates(for: candidate) {
                appendSegment(
                    startIndex: candidate.startIndex,
                    endIndex: candidate.endIndex,
                    coordinates: coordinates,
                    isSnapped: true,
                    to: &routeSegments
                )
            } else {
                appendSegment(
                    startIndex: candidate.startIndex,
                    endIndex: candidate.endIndex,
                    coordinates: [candidate.start.coordinate, candidate.end.coordinate],
                    isSnapped: false,
                    to: &routeSegments
                )
            }
        }

        return RoadSnappedRoute(
            sourceFingerprint: sourceFingerprint,
            sourcePointCount: points.count,
            segments: routeSegments
        )
    }

    private static func shouldAttemptRoadSnap(_ segment: CandidateSegment) -> Bool {
        guard segment.distance >= minimumSnapDistance,
              segment.distance <= maximumSnapDistance else {
            return false
        }

        guard segment.elapsed > 0,
              segment.elapsed <= maximumSnapTimeGap else {
            return false
        }

        let impliedSpeed = segment.distance / segment.elapsed
        guard impliedSpeed <= maximumSnapSpeed else {
            return false
        }

        let maxAccuracy = max(segment.start.horizontalAccuracy, segment.end.horizontalAccuracy)
        guard maxAccuracy <= max(120, segment.distance * 0.75) else {
            return false
        }

        return true
    }

    private static func appendSegment(
        startIndex: Int,
        endIndex: Int,
        coordinates: [CLLocationCoordinate2D],
        isSnapped: Bool,
        to segments: inout [RoadSnappedRouteSegment]
    ) {
        guard coordinates.count >= 2 else { return }

        if !isSnapped,
           let lastSegment = segments.last,
           !lastSegment.isSnapped,
           lastSegment.endIndex == startIndex {
            segments[segments.count - 1] = lastSegment.mergingRaw(
                endIndex: endIndex,
                coordinates: coordinates
            )
        } else {
            segments.append(RoadSnappedRouteSegment(
                startIndex: startIndex,
                endIndex: endIndex,
                coordinates: coordinates,
                isSnapped: isSnapped
            ))
        }
    }

    private static func snappedCoordinates(for segment: CandidateSegment) async -> [CLLocationCoordinate2D]? {
        for transport in preferredTransports(for: segment) {
            guard !Task.isCancelled else { return nil }

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: segment.start.coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: segment.end.coordinate))
            request.transportType = transport
            request.requestsAlternateRoutes = false

            do {
                let response = try await MKDirections(request: request).calculate()
                guard let route = response.routes.first,
                      isPlausible(route: route, for: segment) else {
                    continue
                }

                let coordinates = stitchedCoordinates(
                    route.polyline.roadSnapCoordinates,
                    source: segment.start.coordinate,
                    destination: segment.end.coordinate
                )

                guard coordinates.count >= 2 else { continue }
                return coordinates
            } catch {
                continue
            }
        }

        return nil
    }

    private static func preferredTransports(for segment: CandidateSegment) -> [MKDirectionsTransportType] {
        let impliedSpeed = segment.distance / max(segment.elapsed, 1)
        if impliedSpeed <= walkingSpeedThreshold {
            return [.walking, .automobile]
        }

        return [.automobile, .walking]
    }

    private static func isPlausible(route: MKRoute, for segment: CandidateSegment) -> Bool {
        guard route.distance.isFinite, route.distance > 0 else { return false }
        let maximumRouteDistance = max(segment.distance + 1_000, segment.distance * 4)
        return route.distance <= maximumRouteDistance
    }

    private static func stitchedCoordinates(
        _ routeCoordinates: [CLLocationCoordinate2D],
        source: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        var stitched = [source]

        for coordinate in routeCoordinates where coordinate.isValidRoadSnapCoordinate {
            guard let previous = stitched.last else {
                stitched.append(coordinate)
                continue
            }

            if previous.roadSnapDistance(to: coordinate) > duplicateCoordinateThreshold {
                stitched.append(coordinate)
            }
        }

        if let previous = stitched.last,
           previous.roadSnapDistance(to: destination) <= duplicateCoordinateThreshold {
            stitched[stitched.count - 1] = destination
        } else {
            stitched.append(destination)
        }

        return stitched
    }

    private struct CandidateSegment {
        let startIndex: Int
        let endIndex: Int
        let start: RoadSnappingPoint
        let end: RoadSnappingPoint

        var distance: CLLocationDistance {
            start.coordinate.roadSnapDistance(to: end.coordinate)
        }

        var elapsed: TimeInterval {
            end.timestamp.timeIntervalSince(start.timestamp)
        }
    }
}

private extension MKPolyline {
    var roadSnapCoordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }
        var coordinates = Array(
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}

private extension CLLocationCoordinate2D {
    var isValidRoadSnapCoordinate: Bool {
        CLLocationCoordinate2DIsValid(self) && latitude.isFinite && longitude.isFinite
    }

    func roadSnapDistance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        MKMapPoint(self).distance(to: MKMapPoint(other))
    }
}

// MARK: - Helper Extension

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.5)
        )

        self = MKCoordinateRegion(center: center, span: span)
    }
}

#Preview {
    LocationMapView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self, RecordingSession.self).mainContext,
        locationManager: LocationManager()
    ))
}
