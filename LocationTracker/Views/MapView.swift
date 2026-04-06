import SwiftUI
import MapKit
import SwiftData

struct LocationMapView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedVisit: Visit?
    @State private var showingFilters = false
    @State private var showTravelPath = true
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var filteredVisits: [Visit] {
        viewModel.visitsInDateRange(viewModel.mapDateRange)
    }

    var filteredPoints: [LocationPoint] {
        viewModel.locationPointsInDateRange(viewModel.mapDateRange)
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
                            .stroke(.blue.opacity(0.5), lineWidth: 3)
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
            }
        }
    }

    private func fitMapToContent() {
        guard !filteredVisits.isEmpty else { return }

        let coordinates = filteredVisits.map { $0.coordinate }
        let region = MKCoordinateRegion(coordinates: coordinates)
        cameraPosition = .region(region)
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
