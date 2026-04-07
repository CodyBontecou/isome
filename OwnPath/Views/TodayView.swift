import SwiftUI
import SwiftData
import MapKit

struct TodayView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedPoint: LocationPoint?
    @State private var selectedSegmentMap: SegmentMapSelection?

    @AppStorage("todayPointsSortOption") private var sortOptionRaw = PointSortOption.newestFirst.rawValue
    @AppStorage("todayPointsGroupingOption") private var groupingOptionRaw = PointGroupingOption.tripSegments.rawValue

    private let tripGapThreshold: TimeInterval = 20 * 60
    private let fixedSegmentDuration: TimeInterval = 2 * 60 * 60

    private var sortOption: PointSortOption {
        PointSortOption(rawValue: sortOptionRaw) ?? .newestFirst
    }

    private var groupingOption: PointGroupingOption {
        PointGroupingOption(rawValue: groupingOptionRaw) ?? .tripSegments
    }

    private var sortOptionBinding: Binding<PointSortOption> {
        Binding(
            get: { sortOption },
            set: { sortOptionRaw = $0.rawValue }
        )
    }

    private var groupingOptionBinding: Binding<PointGroupingOption> {
        Binding(
            get: { groupingOption },
            set: { groupingOptionRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if !viewModel.locationManager.hasLocationPermission {
                    PermissionRequestView(locationManager: viewModel.locationManager)
                } else if viewModel.locationPoints.isEmpty {
                    ContentUnavailableView {
                        Label("No Data Points", systemImage: "location.slash")
                    } description: {
                        Text("Location points will appear here as they're tracked.")
                    }
                } else {
                    pointsList
                }
            }
            .navigationTitle(groupingOption == .none ? "All Points" : "Segments")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort") {
                            Picker("Sort", selection: sortOptionBinding) {
                                ForEach(PointSortOption.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                        }

                        Section("Categorize") {
                            Picker("Group", selection: groupingOptionBinding) {
                                ForEach(PointGroupingOption.allCases) { option in
                                    Text(option.title).tag(option)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }

                    Text("\(viewModel.locationPoints.count) points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                viewModel.loadLocationPoints()
            }
            .refreshable {
                viewModel.loadLocationPoints()
            }
            .navigationDestination(item: $selectedPoint) { point in
                PointDetailView(point: point)
            }
            .sheet(item: $selectedSegmentMap) { segment in
                NavigationStack {
                    SegmentMapDetailView(selection: segment)
                }
            }
        }
    }

    private var pointsList: some View {
        List {
            if groupingOption == .none {
                ForEach(sortedPoints) { point in
                    pointRow(point)
                }
            } else {
                ForEach(sectionedPoints) { section in
                    Section {
                        ForEach(orderedPoints(for: section.points)) { point in
                            pointRow(point)
                        }
                    } header: {
                        PointSectionHeader(
                            title: section.title,
                            subtitle: section.subtitle,
                            onShowMap: {
                                selectedSegmentMap = segmentSelection(for: section)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func pointRow(_ point: LocationPoint) -> some View {
        LocationPointRow(point: point)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedPoint = point
            }
    }

    private func segmentSelection(for section: LocationPointSectionData) -> SegmentMapSelection {
        SegmentMapSelection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            points: section.points.sorted { $0.timestamp < $1.timestamp }
        )
    }

    private var sortedPoints: [LocationPoint] {
        let points = viewModel.locationPoints.sorted { $0.timestamp < $1.timestamp }
        return sortOption == .newestFirst ? points.reversed() : points
    }

    private var sectionedPoints: [LocationPointSectionData] {
        let chronologicalPoints = viewModel.locationPoints.sorted { $0.timestamp < $1.timestamp }
        let sections: [LocationPointSectionData]

        switch groupingOption {
        case .none:
            sections = []
        case .tripSegments:
            sections = tripSections(from: chronologicalPoints)
        case .twoHourSegments:
            sections = fixedDurationSections(from: chronologicalPoints)
        case .day:
            sections = daySections(from: chronologicalPoints)
        }

        return sortOption == .newestFirst ? sections.reversed() : sections
    }

    private func orderedPoints(for points: [LocationPoint]) -> [LocationPoint] {
        sortOption == .newestFirst ? points.reversed() : points
    }

    private func tripSections(from points: [LocationPoint]) -> [LocationPointSectionData] {
        guard !points.isEmpty else { return [] }

        var grouped: [[LocationPoint]] = []
        var currentSegment: [LocationPoint] = [points[0]]

        for point in points.dropFirst() {
            guard let previous = currentSegment.last else { continue }
            let gap = point.timestamp.timeIntervalSince(previous.timestamp)

            if gap > tripGapThreshold {
                grouped.append(currentSegment)
                currentSegment = [point]
            } else {
                currentSegment.append(point)
            }
        }

        if !currentSegment.isEmpty {
            grouped.append(currentSegment)
        }

        return grouped.compactMap { makeSection(from: $0, prefix: "Trip") }
    }

    private func fixedDurationSections(from points: [LocationPoint]) -> [LocationPointSectionData] {
        guard let firstPoint = points.first else { return [] }

        var grouped: [[LocationPoint]] = []
        var currentSegment: [LocationPoint] = []
        var segmentStart = firstPoint.timestamp

        for point in points {
            if !currentSegment.isEmpty,
               point.timestamp.timeIntervalSince(segmentStart) >= fixedSegmentDuration {
                grouped.append(currentSegment)
                currentSegment = [point]
                segmentStart = point.timestamp
            } else {
                if currentSegment.isEmpty {
                    segmentStart = point.timestamp
                }
                currentSegment.append(point)
            }
        }

        if !currentSegment.isEmpty {
            grouped.append(currentSegment)
        }

        return grouped.compactMap { makeSection(from: $0, prefix: "2-Hour Segment") }
    }

    private func daySections(from points: [LocationPoint]) -> [LocationPointSectionData] {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: points) { point in
            calendar.startOfDay(for: point.timestamp)
        }

        return groupedByDay.keys.sorted().compactMap { day in
            guard let pointsForDay = groupedByDay[day]?.sorted(by: { $0.timestamp < $1.timestamp }),
                  !pointsForDay.isEmpty else {
                return nil
            }

            return LocationPointSectionData(
                id: "day-\(day.timeIntervalSince1970)",
                title: day.formatted(date: .abbreviated, time: .omitted),
                subtitle: segmentSummary(for: pointsForDay),
                points: pointsForDay
            )
        }
    }

    private func makeSection(from points: [LocationPoint], prefix: String) -> LocationPointSectionData? {
        guard let first = points.first, let last = points.last else { return nil }

        let title = "\(prefix) • \(formattedTimeRange(from: first.timestamp, to: last.timestamp))"
        return LocationPointSectionData(
            id: "\(prefix)-\(first.timestamp.timeIntervalSince1970)-\(last.timestamp.timeIntervalSince1970)-\(points.count)",
            title: title,
            subtitle: segmentSummary(for: points),
            points: points
        )
    }

    private func formattedTimeRange(from start: Date, to end: Date) -> String {
        let sameDay = Calendar.current.isDate(start, inSameDayAs: end)

        if sameDay {
            return "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        }

        return "\(start.formatted(date: .abbreviated, time: .shortened)) - \(end.formatted(date: .abbreviated, time: .shortened))"
    }

    private func segmentSummary(for points: [LocationPoint]) -> String {
        guard let first = points.first, let last = points.last else {
            return "0 points"
        }

        let duration = max(0, last.timestamp.timeIntervalSince(first.timestamp))
        return "\(points.count) points • \(formatDuration(duration)) • \(formatDistance(totalDistance(in: points)))"
    }

    private func totalDistance(in points: [LocationPoint]) -> Double {
        guard points.count > 1 else { return 0 }

        var total: Double = 0
        for index in 1..<points.count {
            total += points[index - 1].distance(to: points[index])
        }

        return total
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0m" }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll

        return formatter.string(from: seconds) ?? "0m"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }

        return String(format: "%.2fkm", meters / 1000)
    }
}

private enum PointSortOption: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestFirst:
            return "Newest First"
        case .oldestFirst:
            return "Oldest First"
        }
    }
}

private enum PointGroupingOption: String, CaseIterable, Identifiable {
    case none
    case tripSegments
    case twoHourSegments
    case day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "No Grouping"
        case .tripSegments:
            return "Trips"
        case .twoHourSegments:
            return "2-Hour Segments"
        case .day:
            return "By Day"
        }
    }
}

private struct LocationPointSectionData: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let points: [LocationPoint]
}

private struct SegmentMapSelection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let points: [LocationPoint]
}

private struct PointSectionHeader: View {
    let title: String
    let subtitle: String
    let onShowMap: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Spacer(minLength: 8)

            if let onShowMap {
                Button(action: onShowMap) {
                    Label("Map", systemImage: "map")
                        .font(.caption.weight(.semibold))
                        .textCase(nil)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SegmentMapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let selection: SegmentMapSelection

    var body: some View {
        VStack(spacing: 0) {
            SessionPathMapView(points: selection.points)

            VStack(alignment: .leading, spacing: 4) {
                Text(selection.title)
                    .font(.subheadline.weight(.semibold))

                Text(selection.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Segment Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct PointDetailView: View {
    let point: LocationPoint
    @State private var cameraPosition: MapCameraPosition

    init(point: LocationPoint) {
        self.point = point
        let region = MKCoordinateRegion(
            center: point.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            Annotation("", coordinate: point.coordinate) {
                Circle()
                    .fill(.blue)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Circle()
                            .stroke(.white, lineWidth: 3)
                    }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .navigationTitle(point.timestamp.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack {
                    Text(String(format: "%.6f, %.6f", point.latitude, point.longitude))
                        .font(.footnote.monospaced())
                    Spacer()
                    Text("±\(Int(point.horizontalAccuracy))m")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let speed = point.speed, speed > 0 {
                    HStack {
                        Text(String(format: "Speed: %.1f m/s", speed))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                if let altitude = point.altitude {
                    HStack {
                        Text(String(format: "Altitude: %.1f m", altitude))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

struct LocationPointRow: View {
    let point: LocationPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(point.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(.headline.monospaced())

            HStack {
                Text(String(format: "%.6f, %.6f", point.latitude, point.longitude))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Spacer()

                if let speed = point.speed, speed > 0 {
                    Text(String(format: "%.1f m/s", speed))
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Text("±\(Int(point.horizontalAccuracy))m")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PermissionRequestView: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Location Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("OwnPath needs access to your location to record the places you visit throughout the day.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if locationManager.authorizationStatus == .denied {
                VStack(spacing: 16) {
                    Text("Location access was denied. Please enable it in Settings.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Button("Allow Always") {
                        locationManager.requestAlwaysAuthorization()
                    }
                    .buttonStyle(.borderedProminent)

                    Text("\"Always\" permission enables background tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview {
    TodayView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
        locationManager: LocationManager()
    ))
}
