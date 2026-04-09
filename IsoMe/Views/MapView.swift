import SwiftUI
import MapKit
import SwiftData

struct LocationMapView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @State private var selectedVisit: Visit?
    @State private var showingFilters = false
    @State private var showTravelPath = true
    @State private var showPointMarkers = true
    @State private var showStartEndMarkers = true
    @State private var showSessionPath = true
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pendingSessionAutoFocus = false
    
    init(viewModel: LocationViewModel) {
        self.viewModel = viewModel
        self.locationManager = viewModel.locationManager
    }
    
    // Minimum distance in meters between points to show as markers
    private let minimumPointDistance: Double = 50

    var filteredVisits: [Visit] {
        viewModel.visitsInDateRange(viewModel.mapDateRange)
    }

    var filteredPoints: [LocationPoint] {
        viewModel.locationPointsInDateRange(viewModel.mapDateRange)
    }
    
    var activeSessionPoints: [LocationPoint] {
        guard locationManager.isContinuousTrackingEnabled else { return [] }
        return viewModel.sessionLocationPoints
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
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                // Date range info overlay
                VStack {
                    HStack {
                        DateRangeChip(range: viewModel.mapDateRange)
                            .onTapGesture {
                                showingFilters = true
                            }
                        Spacer()
                    }
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingFilters = true
                        } label: {
                            Label("Date Range", systemImage: "calendar")
                        }

                        Toggle(isOn: $showTravelPath) {
                            Label("Show Travel Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        }
                        
                        Toggle(isOn: $showSessionPath) {
                            Label("Show Active Session", systemImage: "waveform.path.ecg")
                        }
                        
                        Toggle(isOn: $showPointMarkers) {
                            Label("Show Point Markers", systemImage: "circle.fill")
                        }
                        
                        Toggle(isOn: $showStartEndMarkers) {
                            Label("Show Start/End Markers", systemImage: "flag.fill")
                        }

                        if !activeSessionPoints.isEmpty {
                            Button {
                                fitMapToSession()
                            } label: {
                                Label("Fit Active Session", systemImage: "location.north.line")
                            }
                        }

                        Button {
                            fitMapToContent()
                        } label: {
                            Label("Fit All Visits", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                DateRangeFilterSheet(
                    dateRange: $viewModel.mapDateRange,
                    isPresented: $showingFilters
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

    @State private var startDate: Date
    @State private var endDate: Date

    init(dateRange: Binding<ClosedRange<Date>>, isPresented: Binding<Bool>) {
        _dateRange = dateRange
        _isPresented = isPresented
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
