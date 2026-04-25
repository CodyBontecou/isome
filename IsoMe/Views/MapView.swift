import SwiftUI
import MapKit
import SwiftData

struct LocationMapView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var selectedVisit: Visit?
    @State private var showingFilters = false
    @State private var showingPaywall = false
    @State private var showFilterBar = false
    @State private var showTravelPath = true
    @State private var showPointMarkers = true
    @State private var showStartEndMarkers = true
    @State private var showSessionPath = true
    @State private var showVisitMarkers = true
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pendingSessionAutoFocus = false
    @State private var activePreset: MapDatePreset? = .today
    @AppStorage("showOutliers") private var showOutliers = false

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
        let points = viewModel.locationPointsInDateRange(viewModel.mapDateRange)
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
                    
                    // Live session path
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

                // Bottom-right: filter toggle + optional filter bar
                VStack(spacing: 10) {
                    Spacer()

                    HStack(alignment: .center, spacing: 8) {
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
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeManager: storeManager)
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

struct VisitQuickView: View {
    let visit: Visit
    @Bindable var viewModel: LocationViewModel
    @State private var nearbyMapItem: MKMapItem?
    @State private var isLoadingPlace = false
    @State private var showingPlaceDetail = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top, spacing: 12) {
                    placeIconView

                    VStack(alignment: .leading, spacing: 4) {
                        Text(nearbyMapItem?.name ?? visit.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let address = visit.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let category = nearbyMapItem?.pointOfInterestCategory {
                            Text(category.displayName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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

                // Place actions (phone, website, detail sheet)
                if let item = nearbyMapItem {
                    Divider()

                    VStack(spacing: 0) {
                        if let phone = item.phoneNumber, !phone.isEmpty,
                           let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                            Link(destination: url) {
                                PlaceActionRow(
                                    icon: "phone.fill",
                                    iconColor: .green,
                                    label: phone
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 44)
                        }

                        if let url = item.url {
                            Link(destination: url) {
                                PlaceActionRow(
                                    icon: "globe",
                                    iconColor: .blue,
                                    label: url.host ?? "Website"
                                )
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 44)
                        }

                        Button {
                            showingPlaceDetail = true
                        } label: {
                            PlaceActionRow(
                                icon: "info.circle.fill",
                                iconColor: .blue,
                                label: "View Place Details"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        .task {
            await lookupNearbyPlace()
        }
    }

    // MARK: - Place icon

    @ViewBuilder
    private var placeIconView: some View {
        let category = nearbyMapItem?.pointOfInterestCategory
        let symbolName = category?.sfSymbol ?? "mappin"
        let bgColor = category?.tintColor ?? Color.red

        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isLoadingPlace ? Color(.systemFill) : bgColor)
                .frame(width: 52, height: 52)

            if isLoadingPlace {
                ProgressView()
                    .scaleEffect(0.75)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(duration: 0.3), value: isLoadingPlace)
        .animation(.spring(duration: 0.3), value: nearbyMapItem?.pointOfInterestCategory?.rawValue)
    }

    // MARK: - Nearby place lookup

    private func lookupNearbyPlace() async {
        isLoadingPlace = true
        defer { isLoadingPlace = false }

        let visitLoc = CLLocation(latitude: visit.latitude, longitude: visit.longitude)
        let region = MKCoordinateRegion(
            center: visit.coordinate,
            latitudinalMeters: 300,
            longitudinalMeters: 300
        )

        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)

        guard let response = try? await MKLocalSearch(request: request).start() else { return }

        nearbyMapItem = response.mapItems
            .map { item -> (MKMapItem, CLLocationDistance) in
                let loc = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                return (item, loc.distance(from: visitLoc))
            }
            .filter { $0.1 < 150 }
            .min(by: { $0.1 < $1.1 })
            .map { $0.0 }
    }
}

// MARK: - Place action row

struct PlaceActionRow: View {
    let icon: String
    let iconColor: Color
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(label)
                .foregroundStyle(.primary)
                .font(.subheadline)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - MKPointOfInterestCategory helpers

extension MKPointOfInterestCategory {
    var sfSymbol: String {
        let map: [MKPointOfInterestCategory: String] = [
            .airport: "airplane",
            .amusementPark: "ferriswheel",
            .aquarium: "fish",
            .atm: "banknote",
            .bakery: "birthday.cake",
            .bank: "building.columns.fill",
            .beach: "beach.umbrella",
            .brewery: "mug.fill",
            .cafe: "cup.and.saucer.fill",
            .campground: "tent.fill",
            .carRental: "car.fill",
            .evCharger: "bolt.car.fill",
            .fireStation: "flame.fill",
            .fitnessCenter: "dumbbell.fill",
            .foodMarket: "basket.fill",
            .gasStation: "fuelpump.fill",
            .hospital: "cross.fill",
            .hotel: "bed.double.fill",
            .laundry: "washer.fill",
            .library: "books.vertical.fill",
            .marina: "ferry.fill",
            .movieTheater: "film.fill",
            .museum: "building.columns.fill",
            .nationalPark: "tree.fill",
            .nightlife: "music.note",
            .park: "leaf.fill",
            .parking: "p.circle.fill",
            .pharmacy: "pills.fill",
            .police: "shield.fill",
            .postOffice: "envelope.fill",
            .publicTransport: "bus.fill",
            .restaurant: "fork.knife",
            .restroom: "toilet.fill",
            .school: "graduationcap.fill",
            .stadium: "sportscourt.fill",
            .store: "bag.fill",
            .theater: "theatermasks.fill",
            .university: "graduationcap.fill",
            .winery: "wineglass.fill",
            .zoo: "pawprint.circle.fill",
        ]
        return map[self] ?? "mappin"
    }

    var tintColor: Color {
        let map: [MKPointOfInterestCategory: Color] = [
            .restaurant: .orange,
            .cafe: .orange,
            .bakery: .orange,
            .foodMarket: .orange,
            .brewery: Color(red: 0.6, green: 0.35, blue: 0.1),
            .winery: Color(red: 0.55, green: 0.1, blue: 0.45),
            .hospital: .red,
            .pharmacy: .red,
            .fireStation: .red,
            .park: .green,
            .nationalPark: .green,
            .campground: .green,
            .zoo: .green,
            .airport: .blue,
            .publicTransport: .blue,
            .marina: .blue,
            .store: .indigo,
            .atm: .indigo,
            .bank: .indigo,
            .hotel: Color(red: 0.5, green: 0.2, blue: 0.75),
            .nightlife: .pink,
            .movieTheater: .pink,
            .theater: .pink,
            .amusementPark: .pink,
            .school: .brown,
            .university: .brown,
            .library: .brown,
            .museum: .brown,
            .fitnessCenter: Color(red: 0.9, green: 0.4, blue: 0.0),
            .beach: .cyan,
            .aquarium: .cyan,
            .gasStation: Color(.systemGray),
            .evCharger: Color(.systemGray),
            .carRental: Color(.systemGray),
            .parking: Color(.systemGray),
            .police: Color(red: 0.1, green: 0.25, blue: 0.6),
            .postOffice: Color(red: 0.8, green: 0.5, blue: 0.0),
        ]
        return map[self] ?? Color(.systemGray)
    }

    var displayName: String {
        let map: [MKPointOfInterestCategory: String] = [
            .airport: "Airport",
            .amusementPark: "Amusement Park",
            .aquarium: "Aquarium",
            .atm: "ATM",
            .bakery: "Bakery",
            .bank: "Bank",
            .beach: "Beach",
            .brewery: "Brewery",
            .cafe: "Café",
            .campground: "Campground",
            .carRental: "Car Rental",
            .evCharger: "EV Charger",
            .fireStation: "Fire Station",
            .fitnessCenter: "Gym",
            .foodMarket: "Food Market",
            .gasStation: "Gas Station",
            .hospital: "Hospital",
            .hotel: "Hotel",
            .laundry: "Laundry",
            .library: "Library",
            .marina: "Marina",
            .movieTheater: "Movie Theater",
            .museum: "Museum",
            .nationalPark: "National Park",
            .nightlife: "Nightlife",
            .park: "Park",
            .parking: "Parking",
            .pharmacy: "Pharmacy",
            .police: "Police",
            .postOffice: "Post Office",
            .publicTransport: "Transit",
            .restaurant: "Restaurant",
            .restroom: "Restroom",
            .school: "School",
            .stadium: "Stadium",
            .store: "Store",
            .theater: "Theater",
            .university: "University",
            .winery: "Winery",
            .zoo: "Zoo",
        ]
        return map[self] ?? "Place"
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
                        .fill(isOpen ? AnyShapeStyle(DS.Color.accent) : AnyShapeStyle(.ultraThinMaterial))
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
                    .fill(isActive ? DS.Color.accent : Color.clear)
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
                        .fill(isOn ? DS.Color.accent : Color.clear)
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
