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
    @AppStorage("showOutliers") private var showOutliers = false
    @AppStorage("defaultContinuousTracking") private var defaultContinuousTracking = true
    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true

    init(viewModel: LocationViewModel) {
        self.viewModel = viewModel
        self.locationManager = viewModel.locationManager
    }

    private var isTracking: Bool {
        locationManager.isContinuousTrackingEnabled ||
        (!defaultContinuousTracking && locationManager.isTrackingEnabled)
    }

    private var isContinuousTracking: Bool {
        locationManager.isContinuousTrackingEnabled
    }

    // Minimum distance in meters between points to show as markers
    private let minimumPointDistance: Double = 50

    var filteredVisits: [Visit] {
        viewModel.visitsInDateRange(viewModel.mapDateRange)
    }

    var filteredPoints: [LocationPoint] {
        let points = viewModel.locationPointsInDateRange(viewModel.mapDateRange)
        return showOutliers ? points : points.filter { !$0.isOutlier }
    }

    var activeSessionPoints: [LocationPoint] {
        guard locationManager.isContinuousTrackingEnabled else { return [] }
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
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                                    .overlay {
                                        Circle()
                                            .stroke(.white, lineWidth: 1.5)
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
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                // Bottom liquid-glass tracking + filter controls
                VStack(spacing: 8) {
                    Spacer()

                    MapTrackingControlPill(
                        viewModel: viewModel,
                        locationManager: locationManager,
                        isTracking: isTracking,
                        isContinuousTracking: isContinuousTracking,
                        isExpanded: $trackingPillExpanded,
                        onPrimaryTap: handleTrackingTap
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    if isContinuousTracking,
                       let remaining = locationManager.continuousTrackingRemainingTime {
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
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isContinuousTracking)
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
                    isPresented: $showingFilters,
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

                if locationManager.isContinuousTrackingEnabled {
                    pendingSessionAutoFocus = true
                    attemptAutoFocusSession()
                }
            }
            .onChange(of: locationManager.isContinuousTrackingEnabled) { _, isEnabled in
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

    private func handleTrackingTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if isTracking {
                if isContinuousTracking {
                    viewModel.disableContinuousTracking()
                }
                viewModel.stopTracking()
            } else {
                if defaultLocationTrackingEnabled {
                    viewModel.startTracking()
                }
                if defaultContinuousTracking {
                    viewModel.enableContinuousTracking()
                }
            }
        }
    }
}

// MARK: - Tracking Control Pills

struct MapTrackingControlPill: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject var locationManager: LocationManager
    let isTracking: Bool
    let isContinuousTracking: Bool
    @Binding var isExpanded: Bool
    let onPrimaryTap: () -> Void

    @State private var pulseOpacity: Double = 1.0

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
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                if isExpanded {
                    statsBlock
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

            if isContinuousTracking {
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    Text(viewModel.formattedSessionTrackingDuration)
                        .font(TE.mono(.subheadline, weight: .semibold))
                        .foregroundStyle(TE.textMuted)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            } else {
                Text(isTracking ? "TRACKING" : "STANDBY")
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

            Text("\(viewModel.sessionLocationPoints.count) PTS")
                .font(TE.mono(.caption, weight: .medium))
                .foregroundStyle(TE.textMuted)
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimaryTap) {
            Image(systemName: isTracking ? "stop.fill" : "play.fill")
                .font(.system(size: 12, weight: .bold))
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
        }
        .buttonStyle(.plain)
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
                    .fill(visit.isCurrentVisit ? .blue : .red)
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)

                Image(systemName: "mappin")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundStyle(.white)
            }

            Triangle()
                .fill(visit.isCurrentVisit ? .blue : .red)
                .frame(width: 10, height: 8)
        }
        .animation(.spring(duration: 0.2), value: isSelected)
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
            }
            .shadow(color: .green.opacity(0.4), radius: 4, y: 2)
        }
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) {
                showingTooltip.toggle()
            }
        }
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
            }
            .shadow(color: .red.opacity(0.4), radius: 4, y: 2)
        }
        .onTapGesture {
            withAnimation(.spring(duration: 0.2)) {
                showingTooltip.toggle()
            }
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
                .frame(width: 42, height: 42)
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
        }
        .buttonStyle(.plain)
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
                        isActive: activePreset == preset
                    ) {
                        onSelectPreset(preset)
                    }
                }

                PresetPill(
                    label: "Custom",
                    icon: "calendar",
                    isActive: activePreset == nil
                ) {
                    onSelectCustom()
                }

                PillSeparator()

                LayerToggleButton(systemImage: "mappin.circle.fill", isOn: $showVisitMarkers)
                LayerToggleButton(systemImage: "point.topleft.down.to.point.bottomright.curvepath", isOn: $showTravelPath)
                LayerToggleButton(systemImage: "smallcircle.filled.circle", isOn: $showPointMarkers)
                LayerToggleButton(systemImage: "flag.fill", isOn: $showStartEndMarkers)
                if hasSessionPoints {
                    LayerToggleButton(systemImage: "waveform.path.ecg", isOn: $showSessionPath)
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
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill(isActive ? TE.accent : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }
}

struct LayerToggleButton: View {
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) {
                isOn.toggle()
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(isOn ? Color.white : Color.primary.opacity(0.55))
                .background {
                    Circle()
                        .fill(isOn ? TE.accent : Color.clear)
                }
        }
        .buttonStyle(.plain)
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
                .frame(width: 32, height: 32)
                .foregroundStyle(Color.primary.opacity(0.7))
        }
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
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}
