import SwiftUI
import MapKit
import SwiftData

struct LocationMapView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    var body: some View {
        NavigationStack {
            ZStack {
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
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                                    .overlay {
                                        Circle()
                                            .stroke(.white, lineWidth: 1.5)
                                    }
                                    .accessibilityHidden(true)
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
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
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
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) {
                                showFilterBar.toggle()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82), value: isTracking)
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

    private func dismissDiscordPromo() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82)) {
            discordPromoDismissed = true
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

    private var mapAccessibilitySummary: String {
        var parts: [String] = []
        parts.append("\(filteredVisits.count) \(filteredVisits.count == 1 ? "visit" : "visits")")
        parts.append("\(filteredPoints.count) \(filteredPoints.count == 1 ? "path point" : "path points")")

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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(visit.isCurrentVisit ? .blue : .red)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                    .accessibilityHidden(true)

                Image(systemName: "mappin")
                    .font(isSelected ? .title3 : .callout)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            Triangle()
                .fill(visit.isCurrentVisit ? .blue : .red)
                .frame(width: 10, height: 8)
                .accessibilityHidden(true)
        }
        .frame(minWidth: 44, minHeight: 44)
        .animation(reduceMotion ? nil : .spring(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(visit.accessibilityLabel)
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
            VStack(spacing: 2) {
                if showingTooltip {
                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }

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
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Path start")
        .accessibilityValue(timestamp.formatted(date: .abbreviated, time: .shortened))
        .accessibilityHint(showingTooltip ? "Hides the start time." : "Shows the start time.")
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
            VStack(spacing: 2) {
                if showingTooltip {
                    Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }

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
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Path end")
        .accessibilityValue(timestamp.formatted(date: .abbreviated, time: .shortened))
        .accessibilityHint(showingTooltip ? "Hides the end time." : "Shows the end time.")
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
            Form {
                Section("Quick Select") {
                    Button("Today") {
                        let today = Calendar.current.startOfDay(for: Date())
                        startDate = today
                        endDate = Date()
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

                Section("Vehicle") {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        Text("All Vehicles").tag(nil as UUID?)
                        ForEach(vehicles.filter { !$0.isArchived }) { vehicle in
                            Text(vehicle.name).tag(Optional(vehicle.id))
                        }
                    }
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
    let visit: Visit
    @Bindable var viewModel: LocationViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let address = visit.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if visit.isCurrentVisit {
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

                Divider()

                LabeledContent("Vehicle", value: viewModel.vehicleName(for: visit.vehicleID))

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

                if let vehicleName = visit.vehicleName {
                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: visit.isVehicleAutoDetected ? "bluetooth" : "car.fill")
                            .font(.caption)
                            .foregroundStyle(visit.isVehicleAutoDetected ? .blue : .secondary)
                        Text(vehicleName)
                            .font(.subheadline)
                        if visit.isVehicleAutoDetected {
                            Text("AUTO")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                NavigationLink {
                    VisitDetailView(visit: visit, viewModel: viewModel)
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Details")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
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
                    LayerToggleButton(systemImage: "mappin.circle.fill", label: "Visit markers", isOn: $showVisitMarkers)
                }
                LayerToggleButton(systemImage: "point.topleft.down.to.point.bottomright.curvepath", label: "Travel path", isOn: $showTravelPath)
                LayerToggleButton(systemImage: "smallcircle.filled.circle", label: "Point markers", isOn: $showPointMarkers)
                LayerToggleButton(systemImage: "flag.fill", label: "Start and end markers", isOn: $showStartEndMarkers)
                if hasSessionPoints {
                    LayerToggleButton(systemImage: "waveform.path.ecg", label: "Active session path", isOn: $showSessionPath)
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

struct LayerToggleButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.25)) {
                isOn.toggle()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(isOn ? Color.white : Color.primary.opacity(0.55))
                .background {
                    Circle()
                        .fill(isOn ? TE.accent : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "Shown" : "Hidden")
        .accessibilityHint("Toggles this map layer.")
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
