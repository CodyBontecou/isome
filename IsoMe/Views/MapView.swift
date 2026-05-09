import SwiftUI
import MapKit
import SwiftData

struct LocationMapView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @State private var selectedVisit: Visit?
    @State private var showingFilters = false
    @State private var showFilterBar = false
    @State private var trackingPillExpanded = false
    @State private var showTravelPath = true
    @State private var showPointMarkers = true
    @State private var showStartEndMarkers = true
    @State private var showSessionPath = true
    @State private var showVisitMarkers = true
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pendingSessionAutoFocus = false
    @State private var activePreset: MapDatePreset? = .today
    @State private var selectedLocationPoint: LocationPoint?
    @State private var selectedVehicleID: UUID?
    @AppStorage("showOutliers") private var showOutliers = false
    @AppStorage("discordPromoDismissed") private var discordPromoDismissed = false

    init(viewModel: LocationViewModel) {
        self.viewModel = viewModel
        self.locationManager = viewModel.locationManager
    }

    private var isTracking: Bool {
        locationManager.isTrackingEnabled
    }

    private var showsVisitSurfaces: Bool {
        !locationManager.isDrivesOnlyMode
    }

    // Minimum distance in meters between points to show as markers
    private let minimumPointDistance: Double = 50

    var filteredVisits: [Visit] {
        guard showsVisitSurfaces else { return [] }
        return viewModel.visitsInDateRange(viewModel.mapDateRange)
            .filter { selectedVehicleID == nil || $0.vehicleID == selectedVehicleID }
    }

    var filteredPoints: [LocationPoint] {
        let points = viewModel.locationPointsInDateRange(viewModel.mapDateRange)
            .filter { selectedVehicleID == nil || $0.vehicleID == selectedVehicleID }
        return showOutliers ? points : points.filter { !$0.isOutlier }
    }

    var activeSessionPoints: [LocationPoint] {
        guard locationManager.isTrackingEnabled else { return [] }
        let points = viewModel.sessionLocationPoints
        return showOutliers ? points : points.filter { !$0.isOutlier }
    }
    
    var spacedPoints: [LocationPoint] {
        guard !filteredPoints.isEmpty else { return [] }
        
        var result: [LocationPoint] = [filteredPoints[0]]
        
        for point in filteredPoints.dropFirst() {
            if let lastPoint = result.last {
                let distance = lastPoint.distance(to: point)
                if distance >= minimumPointDistance {
                    result.append(point)
                }
            }
        }
        
        return result
    }

    private var tappablePoints: [LocationPoint] {
        var points = (showTravelPath || showPointMarkers || showStartEndMarkers) ? filteredPoints : []

        if showSessionPath {
            let existingIDs = Set(points.map(\.id))
            points.append(contentsOf: activeSessionPoints.filter { !existingIDs.contains($0.id) })
        }

        return points
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { proxy in
                    Map(position: $cameraPosition, selection: $selectedVisit) {
                    // Current user location
                    UserAnnotation()

                    // Travel path from location points
                    if showTravelPath && !filteredPoints.isEmpty {
                        let coordinates = filteredPoints.map { $0.coordinate }
                        MapPolyline(coordinates: coordinates)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .blue.opacity(0.7), .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 4
                            )
                    }
                    
                    // Live session path (moved from Track tab)
                    if showSessionPath && activeSessionPoints.count >= 2 {
                        let sessionCoordinates = activeSessionPoints.map { $0.coordinate }
                        MapPolyline(coordinates: sessionCoordinates)
                            .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                    
                    if showSessionPath, let firstSessionPoint = activeSessionPoints.first {
                        Annotation("Session Start", coordinate: firstSessionPoint.coordinate) {
                            StartMarker()
                        }
                    }
                    
                    if showSessionPath,
                       let lastSessionPoint = activeSessionPoints.last,
                       activeSessionPoints.count > 1 {
                        Annotation("Current", coordinate: lastSessionPoint.coordinate) {
                            CurrentLocationMarker()
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
                                LocationPointMarker(
                                    isSelected: selectedLocationPoint?.id == point.id
                                )
                                .onTapGesture {
                                    withAnimation(.spring(duration: 0.2)) {
                                        selectedLocationPoint = point
                                    }
                                }
                            }
                        }
                    }

                    if let selectedLocationPoint {
                        Annotation("", coordinate: selectedLocationPoint.coordinate, anchor: .bottom) {
                            LocationPointTimestampCallout(point: selectedLocationPoint) {
                                withAnimation(.spring(duration: 0.2)) {
                                    self.selectedLocationPoint = nil
                                }
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
                                VisitMarker(visit: visit, isSelected: selectedVisit?.id == visit.id)
                            }
                            .tag(visit)
                        }
                    }
                }
                    .onTapGesture(coordinateSpace: .local) { point in
                        selectNearestLocationPoint(to: point, proxy: proxy)
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if !discordPromoDismissed {
                            DiscordPromoBanner(onDismiss: dismissDiscordPromo)
                                .padding(.horizontal, 12)
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: discordPromoDismissed)
                }

                // Bottom liquid-glass tracking + filter controls
                VStack(spacing: 8) {
                    Spacer()

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
                                showsVisitLayer: showsVisitSurfaces,
                                hasSessionPoints: !activeSessionPoints.isEmpty,
                                onSelectPreset: { preset in
                                    activePreset = preset
                                    viewModel.mapDateRange = preset.range()
                                },
                                onSelectCustom: {
                                    showingFilters = true
                                },
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
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                showFilterBar.toggle()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isTracking)
                .onChange(of: isTracking) { _, newValue in
                    if !newValue {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            trackingPillExpanded = false
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingFilters) {
                DateRangeFilterSheet(
                    dateRange: $viewModel.mapDateRange,
                    selectedVehicleID: $selectedVehicleID,
                    isPresented: $showingFilters,
                    vehicles: viewModel.vehicles,
                    onApply: { activePreset = nil }
                )
            }
            .sheet(item: $selectedVisit) { visit in
                VisitQuickView(visit: visit, viewModel: viewModel)
                    .presentationDetents([.medium])
            }
            .onAppear {
                viewModel.loadAllVisits()
                viewModel.loadLocationPoints()

                if locationManager.isTrackingEnabled {
                    pendingSessionAutoFocus = true
                    attemptAutoFocusSession()
                }
            }
            .onChange(of: locationManager.isTrackingEnabled) { _, isEnabled in
                pendingSessionAutoFocus = isEnabled
                if isEnabled {
                    attemptAutoFocusSession()
                }
            }
            .onChange(of: locationManager.trackingMode) { _, _ in
                selectedVisit = nil
                if locationManager.isDrivesOnlyMode {
                    showVisitMarkers = false
                } else {
                    showVisitMarkers = true
                }
            }
            .onChange(of: activeSessionPoints.count) { _, _ in
                if pendingSessionAutoFocus {
                    attemptAutoFocusSession()
                }
            }
        }
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

    private func selectNearestLocationPoint(to tapPoint: CGPoint, proxy: MapProxy) {
        guard !tappablePoints.isEmpty else {
            selectedLocationPoint = nil
            return
        }

        let nearest = tappablePoints
            .compactMap { point -> (point: LocationPoint, distance: CGFloat)? in
                guard let projectedPoint = proxy.convert(point.coordinate, to: .local) else {
                    return nil
                }

                return (
                    point,
                    hypot(projectedPoint.x - tapPoint.x, projectedPoint.y - tapPoint.y)
                )
            }
            .min { $0.distance < $1.distance }

        withAnimation(.spring(duration: 0.2)) {
            if let nearest, nearest.distance <= 32 {
                selectedLocationPoint = nearest.point
            } else {
                selectedLocationPoint = nil
            }
        }
    }

    private func dismissDiscordPromo() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            discordPromoDismissed = true
        }
    }

    private func handleTrackingTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isTracking {
                viewModel.stopTracking()
            } else {
                viewModel.startTracking()
            }
        }
    }
}

// MARK: - Location Point Selection

struct LocationPointMarker: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? TE.accent : .blue)
            .frame(width: isSelected ? 12 : 8, height: isSelected ? 12 : 8)
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: isSelected ? 2 : 1.5)
            }
            .contentShape(Circle())
            .shadow(color: .black.opacity(isSelected ? 0.22 : 0), radius: 4, y: 2)
            .animation(.spring(duration: 0.2), value: isSelected)
    }
}

struct LocationPointTimestampCallout: View {
    let point: LocationPoint
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(TE.mono(.caption, weight: .semibold))
                    .foregroundStyle(TE.textPrimary)

                Text(coordinateText)
                    .font(TE.mono(.caption2, weight: .medium))
                    .foregroundStyle(TE.textMuted)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TE.textMuted)
                    .frame(width: 22, height: 22)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 5)
        }
        .offset(y: -12)
    }

    private var coordinateText: String {
        String(format: "%.5f, %.5f", point.latitude, point.longitude)
    }
}

// MARK: - Tracking Control Pills

struct MapTrackingControlPill: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject var locationManager: LocationManager
    let isTracking: Bool
    @Binding var isExpanded: Bool
    let onPrimaryTap: () -> Void

    @State private var pulseOpacity: Double = 1.0

    private var statusAccessibilityLabel: String {
        if isTracking {
            return "Tracking active"
        }
        return "Tracking standby"
    }

    private var statusAccessibilityValue: String {
        if isTracking {
            return "Elapsed time \(viewModel.formattedSessionTrackingDuration)"
        }
        return "Not currently tracking"
    }

    private var statsAccessibilityLabel: String {
        "Live tracking stats"
    }

    private var statsAccessibilityValue: String {
        "\(viewModel.formattedSessionDistance), \(viewModel.sessionLocationPoints.count) points, elapsed time \(viewModel.formattedSessionTrackingDuration)"
    }

    private var primaryButtonAccessibilityLabel: String {
        isTracking ? "Stop tracking" : "Start tracking"
    }

    var body: some View {
        HStack(spacing: 10) {
            if isTracking {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        isExpanded.toggle()
                    }
                } label: {
                    statusBlock
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(statusAccessibilityLabel)
                .accessibilityValue(statusAccessibilityValue)
                .accessibilityHint(isExpanded ? "Collapses live tracking stats." : "Expands live tracking stats.")
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                if isExpanded {
                    statsBlock
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(statsAccessibilityLabel)
                        .accessibilityValue(statsAccessibilityValue)
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
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isTracking)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
        .onAppear { pulseOpacity = 0.35 }
        .accessibilityElement(children: .contain)
    }

    private var statusBlock: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isTracking ? TE.accent : TE.textMuted.opacity(0.35))
                .frame(width: 7, height: 7)
                .opacity(isTracking ? pulseOpacity : 1.0)
                .animation(
                    isTracking
                        ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseOpacity
                )
                .accessibilityHidden(true)

            if isTracking {
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    Text(viewModel.formattedSessionTrackingDuration)
                        .font(TE.mono(.subheadline, weight: .semibold))
                        .foregroundStyle(TE.textMuted)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .contentTransition(.numericText())
                }
            } else {
                Text("STANDBY")
                    .font(TE.mono(.caption, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(TE.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private var statsBlock: some View {
        HStack(spacing: 8) {
            Text(viewModel.formattedSessionDistance)
                .font(TE.mono(.caption, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 12)
                .accessibilityHidden(true)

            Text("\(viewModel.sessionLocationPoints.count) PTS")
                .font(TE.mono(.caption, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimaryTap) {
            Image(systemName: isTracking ? "stop.fill" : "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
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
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryButtonAccessibilityLabel)
        .accessibilityHint(isTracking ? "Stops the current location tracking session." : "Starts a new location tracking session.")
        .sensoryFeedback(.impact(flexibility: .solid), trigger: isTracking)
    }
}

struct MapAutoOffPill: View {
    let remaining: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .accessibilityHidden(true)

            Text("AUTO-OFF  \(formatTime(remaining))")
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(TE.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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
        .accessibilityLabel("Auto-off timer")
        .accessibilityValue(formatTime(remaining))
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)H \(minutes)M" }
        return "\(minutes) MIN"
    }
}

struct VisitMarker: View {
    let visit: Visit
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(visit.purpose.mapTint)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)

                Image(systemName: visit.purpose.iconName)
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            Triangle()
                .fill(visit.purpose.mapTint)
                .frame(width: 10, height: 8)
        }
        .animation(.spring(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(visit.displayName)
        .accessibilityValue(visit.isCurrentVisit ? "Current visit" : "Visit")
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

// MARK: - Path Start/End Markers

struct PathStartMarker: View {
    let timestamp: Date
    @State private var showingTooltip = false
    
    var body: some View {
        VStack(spacing: 2) {
            if showingTooltip {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            
            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: 28, height: 28)
                
                Image(systemName: "flag.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .shadow(color: .green.opacity(0.4), radius: 4, y: 2)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) {
                showingTooltip.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Path start")
        .accessibilityValue(timestamp.formatted(date: .abbreviated, time: .shortened))
        .accessibilityAddTraits(.isButton)
    }
}

struct PathEndMarker: View {
    let timestamp: Date
    @State private var showingTooltip = false
    
    var body: some View {
        VStack(spacing: 2) {
            if showingTooltip {
                Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
            
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 28, height: 28)
                
                Image(systemName: "flag.checkered")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .shadow(color: .red.opacity(0.4), radius: 4, y: 2)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) {
                showingTooltip.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Path end")
        .accessibilityValue(timestamp.formatted(date: .abbreviated, time: .shortened))
        .accessibilityAddTraits(.isButton)
    }
}

struct DateRangeChip: View {
    let range: ClosedRange<Date>

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
                .accessibilityHidden(true)
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
    @Binding var selectedVehicleID: UUID?
    @Binding var isPresented: Bool
    let vehicles: [Vehicle]
    var onApply: (() -> Void)? = nil

    @State private var startDate: Date
    @State private var endDate: Date

    init(
        dateRange: Binding<ClosedRange<Date>>,
        selectedVehicleID: Binding<UUID?> = .constant(nil),
        isPresented: Binding<Bool>,
        vehicles: [Vehicle] = [],
        onApply: (() -> Void)? = nil
    ) {
        _dateRange = dateRange
        _selectedVehicleID = selectedVehicleID
        _isPresented = isPresented
        self.vehicles = vehicles
        self.onApply = onApply
        _startDate = State(initialValue: dateRange.wrappedValue.lowerBound)
        _endDate = State(initialValue: dateRange.wrappedValue.upperBound)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        quickSelectSection
                        customRangeSection
                        vehicleSection
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(TE.textMuted)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        dateRange = startDate...endDate
                        onApply?()
                        isPresented = false
                    }
                    .foregroundStyle(TE.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var quickSelectSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "QUICK SELECT")

            TECard {
                quickSelectRow("TODAY", showDivider: true) {
                    let today = Calendar.current.startOfDay(for: Date())
                    startDate = today
                    endDate = Date()
                }

                quickSelectRow("LAST 7 DAYS", showDivider: true) {
                    endDate = Date()
                    startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
                }

                quickSelectRow("LAST 30 DAYS", showDivider: true) {
                    endDate = Date()
                    startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
                }

                quickSelectRow("ALL TIME", showDivider: false) {
                    startDate = Date.distantPast
                    endDate = Date()
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var customRangeSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "CUSTOM RANGE")

            TECard {
                TERow {
                    datePickerRow("FROM", selection: $startDate)
                }
                TERow(showDivider: false) {
                    datePickerRow("TO", selection: $endDate)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var vehicleSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "VEHICLE")

            TECard {
                TERow(showDivider: false) {
                    HStack(spacing: 12) {
                        Text("SHOW")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)
                        Spacer()
                        Picker("Vehicle", selection: $selectedVehicleID) {
                            Text("All Vehicles").tag(nil as UUID?)
                            ForEach(vehicles.filter { !$0.isArchived }) { vehicle in
                                Text(vehicle.name).tag(Optional(vehicle.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(TE.accent)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func quickSelectRow(_ title: String, showDivider: Bool, action: @escaping () -> Void) -> some View {
        TERow(showDivider: showDivider) {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text(title)
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

    private func datePickerRow(_ title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(TE.mono(.caption, weight: .medium))
                .tracking(1)
                .foregroundStyle(TE.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .tint(TE.accent)
        }
    }
}

struct VisitQuickView: View {
    let visit: Visit
    @Bindable var viewModel: LocationViewModel
    @State private var subPurposeText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        summarySection
                        classificationSection
                        detailsSection
                        notesSection
                        actionSection
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                subPurposeText = visit.subPurpose ?? ""
            }
        }
    }

    private var summarySection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "TRIP")

            TECard {
                TERow(showDivider: false) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(visit.displayName.uppercased())
                                .font(TE.mono(.caption, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)

                            if let address = visit.address {
                                Text(address)
                                    .font(TE.mono(.caption2))
                                    .foregroundStyle(TE.textMuted)
                            }
                        }

                        Spacer()

                        if visit.isCurrentVisit {
                            Text("NOW")
                                .font(TE.mono(.caption2, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(TE.accent, in: Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var classificationSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "CLASSIFICATION")

            TECard {
                TERow(showDivider: visit.purpose == .business) {
                    HStack(spacing: 0) {
                        ForEach(Array(TripPurpose.allCases.enumerated()), id: \.element.id) { index, purpose in
                            purposeSegment(purpose)
                            if index < TripPurpose.allCases.count - 1 {
                                Rectangle()
                                    .fill(TE.border)
                                    .frame(width: 1)
                            }
                        }
                    }
                    .frame(height: 44)
                }

                if visit.purpose == .business {
                    TERow(showDivider: false) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("PURPOSE")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer(minLength: 12)
                            TextField("Sub-purpose", text: $subPurposeText)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textMuted)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .onSubmit {
                                    viewModel.updateVisitClassification(visit, purpose: .business, subPurpose: subPurposeText)
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "DETAILS")

            TECard {
                infoRow("ARRIVED", value: visit.arrivedAt.formatted(date: .abbreviated, time: .shortened))

                if let departed = visit.departedAt {
                    infoRow("DEPARTED", value: departed.formatted(date: .abbreviated, time: .shortened))
                }

                infoRow("DURATION", value: visit.formattedDuration)
                infoRow("VEHICLE", value: viewModel.vehicleName(for: visit.vehicleID), showDivider: visit.vehicleName != nil)

                if let vehicleName = visit.vehicleName {
                    TERow(showDivider: false) {
                        HStack(spacing: 8) {
                            Image(systemName: visit.isVehicleAutoDetected ? "bluetooth" : "car.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(visit.isVehicleAutoDetected ? TE.accent : TE.textMuted)
                            Text(vehicleName.uppercased())
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            if visit.isVehicleAutoDetected {
                                Text("AUTO")
                                    .font(TE.mono(.caption2, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = visit.notes, !notes.isEmpty {
            VStack(spacing: 0) {
                TESectionHeader(title: "NOTES")

                TECard {
                    TERow(showDivider: false) {
                        Text(notes)
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIONS")

            TECard {
                TERow(showDivider: false) {
                    NavigationLink {
                        VisitDetailView(visit: visit, viewModel: viewModel)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TE.accent)
                            Text("DETAILS")
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
            .padding(.horizontal, 16)
        }
    }

    private func infoRow(_ label: String, value: String, showDivider: Bool = true) -> some View {
        TERow(showDivider: showDivider) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(TE.mono(.caption, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)
                Spacer(minLength: 16)
                Text(value)
                    .font(TE.mono(.caption2, weight: .medium))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(TE.textMuted)
            }
        }
    }

    private func purposeSegment(_ purpose: TripPurpose) -> some View {
        let isSelected = visit.purpose == purpose
        return Button {
            viewModel.updateVisitClassification(visit, purpose: purpose, subPurpose: subPurposeText)
            if purpose != .business {
                subPurposeText = ""
            }
        } label: {
            Text(purpose.label.uppercased())
                .font(TE.mono(.caption2, weight: isSelected ? .bold : .medium))
                .tracking(1)
                .foregroundStyle(isSelected ? purpose.mapTint : TE.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isSelected ? purpose.mapTint.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Filter Bar

enum MapDatePreset: CaseIterable, Hashable {
    case today, sevenDays, thirtyDays, all

    var label: String {
        switch self {
        case .today: return "Today"
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .all: return "All"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .today: return "Today"
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
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOpen ? "xmark" : "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
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
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "Close map filters" : "Open map filters")
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
    let showsVisitLayer: Bool
    let hasSessionPoints: Bool
    let onSelectPreset: (MapDatePreset) -> Void
    let onSelectCustom: () -> Void
    let onFitContent: () -> Void
    let onFitSession: (() -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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

                if showsVisitLayer {
                    LayerToggleButton(systemImage: "mappin.circle.fill", accessibilityLabel: "Visit markers", isOn: $showVisitMarkers)
                }
                LayerToggleButton(systemImage: "point.topleft.down.to.point.bottomright.curvepath", accessibilityLabel: "Travel path", isOn: $showTravelPath)
                LayerToggleButton(systemImage: "smallcircle.filled.circle", accessibilityLabel: "Point markers", isOn: $showPointMarkers)
                LayerToggleButton(systemImage: "flag.fill", accessibilityLabel: "Start and end markers", isOn: $showStartEndMarkers)
                if hasSessionPoints {
                    LayerToggleButton(systemImage: "waveform.path.ecg", accessibilityLabel: "Active session path", isOn: $showSessionPath)
                }

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
                        .font(.system(size: 11, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background {
                Capsule()
                    .fill(isActive ? TE.accent : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityValue(isActive ? "Selected" : "Not selected")
    }
}

struct LayerToggleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                isOn.toggle()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(isOn ? Color.white : Color.primary.opacity(0.55))
                .background {
                    Circle()
                        .fill(isOn ? TE.accent : Color.clear)
                }
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "Shown" : "Hidden")
    }
}

struct PillSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
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
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Color.primary.opacity(0.7))
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Fit map")
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
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self, Vehicle.self).mainContext,
        locationManager: LocationManager()
    ))
}
