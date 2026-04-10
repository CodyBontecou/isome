import SwiftUI
import SwiftData
import MapKit

struct TodayView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedPoint: LocationPoint?
    @State private var selectedSegmentMap: SegmentMapSelection?
    @State private var expandedSections: Set<String> = []

    @AppStorage("todayPointsSortOption") private var sortOptionRaw = PointSortOption.newestFirst.rawValue
    @AppStorage("todayPointsGroupingOption") private var groupingOptionRaw = PointGroupingOption.tripSegments.rawValue
    @AppStorage("usesMetricDistanceUnits") private var usesMetricDistanceUnits = true

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
            ZStack {
                TE.surface.ignoresSafeArea()

                Group {
                    if !viewModel.locationManager.hasLocationPermission {
                        PermissionRequestView(locationManager: viewModel.locationManager)
                    } else if viewModel.locationPoints.isEmpty {
                        emptyState
                    } else {
                        pointsList
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(groupingOption == .none ? "ALL POINTS" : "SEGMENTS")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(TE.textMuted)
                }
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
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(TE.textPrimary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(viewModel.locationPoints.count) PTS")
                        .font(TE.mono(.caption2, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(TE.textMuted)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "location.slash")
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .foregroundStyle(TE.textMuted.opacity(0.5))

            Text("NO DATA POINTS")
                .font(TE.mono(.caption, weight: .semibold))
                .tracking(2)
                .foregroundStyle(TE.textMuted)

            Text("Location points will appear here as they're tracked.")
                .font(TE.mono(.caption2, weight: .regular))
                .foregroundStyle(TE.textMuted.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Points List

    private var pointsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if groupingOption == .none {
                    TECard {
                        VStack(spacing: 0) {
                            ForEach(Array(sortedPoints.enumerated()), id: \.element.id) { index, point in
                                pointRow(point, isLast: index == sortedPoints.count - 1)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                } else {
                    ForEach(sectionedPoints) { section in
                        VStack(spacing: 0) {
                            sectionHeader(section)

                            if expandedSections.contains(section.id) {
                                TECard {
                                    VStack(spacing: 0) {
                                        let ordered = orderedPoints(for: section.points)
                                        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, point in
                                            pointRow(point, isLast: index == ordered.count - 1)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: LocationPointSectionData) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if expandedSections.contains(section.id) {
                        expandedSections.remove(section.id)
                    } else {
                        expandedSections.insert(section.id)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TE.textMuted)
                        .rotationEffect(.degrees(expandedSections.contains(section.id) ? 90 : 0))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title.uppercased())
                            .font(TE.mono(.caption2, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)

                        Text(section.subtitle.uppercased())
                            .font(TE.mono(.caption2, weight: .regular))
                            .tracking(0.5)
                            .foregroundStyle(TE.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                selectedSegmentMap = segmentSelection(for: section)
            } label: {
                HStack(spacing: 4) {
                    Text("MAP")
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(TE.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Point Row

    private func pointRow(_ point: LocationPoint, isLast: Bool) -> some View {
        Button {
            selectedPoint = point
        } label: {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textPrimary)

                        HStack(spacing: 8) {
                            Text(String(format: "%.5f, %.5f", point.latitude, point.longitude))
                                .font(TE.mono(.caption2, weight: .regular))
                                .foregroundStyle(TE.textMuted)

                            Text("±\(Int(point.horizontalAccuracy))m")
                                .font(TE.mono(.caption2, weight: .regular))
                                .foregroundStyle(TE.textMuted.opacity(0.6))
                        }
                    }

                    Spacer()

                    if let speed = point.speed, speed > 0 {
                        Text(String(format: "%.1f m/s", speed))
                            .font(TE.mono(.caption2, weight: .medium))
                            .foregroundStyle(TE.accent)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TE.textMuted.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !isLast {
                    Divider()
                        .background(TE.border)
                        .padding(.leading, 16)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data helpers

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
        DistanceFormatter.format(meters: meters, usesMetric: usesMetricDistanceUnits)
    }
}

// MARK: - Supporting Types

private enum PointSortOption: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newestFirst:
            return String(localized: "Newest First")
        case .oldestFirst:
            return String(localized: "Oldest First")
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
            return String(localized: "No Grouping")
        case .tripSegments:
            return String(localized: "Trips")
        case .twoHourSegments:
            return String(localized: "2-Hour Segments")
        case .day:
            return String(localized: "By Day")
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

// MARK: - Segment Map Detail

private struct SegmentMapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let selection: SegmentMapSelection

    var body: some View {
        VStack(spacing: 0) {
            SessionPathMapView(points: selection.points)

            VStack(alignment: .leading, spacing: 4) {
                Text(selection.title.uppercased())
                    .font(TE.mono(.caption, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(TE.textPrimary)

                Text(selection.subtitle.uppercased())
                    .font(TE.mono(.caption2, weight: .regular))
                    .tracking(0.5)
                    .foregroundStyle(TE.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(TE.surface)
        }
        .background(TE.surface)
        .navigationTitle("Segment Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(TE.mono(.caption, weight: .semibold))
            }
        }
    }
}

// MARK: - Point Detail

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
                    .fill(TE.accent)
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
                        .font(TE.mono(.caption, weight: .medium))
                        .foregroundStyle(TE.textPrimary)
                    Spacer()
                    Text("±\(Int(point.horizontalAccuracy))m")
                        .font(TE.mono(.caption2, weight: .regular))
                        .foregroundStyle(TE.textMuted)
                }
                if let speed = point.speed, speed > 0 {
                    HStack {
                        Text(String(format: "SPEED  %.1f M/S", speed))
                            .font(TE.mono(.caption2, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                        Spacer()
                    }
                }
                if let altitude = point.altitude {
                    HStack {
                        Text(String(format: "ALT  %.1f M", altitude))
                            .font(TE.mono(.caption2, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(TE.surface)
        }
    }
}

// MARK: - Location Point Row

struct LocationPointRow: View {
    let point: LocationPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(point.timestamp.formatted(date: .abbreviated, time: .standard))
                .font(TE.mono(.caption, weight: .medium))
                .foregroundStyle(TE.textPrimary)

            HStack {
                Text(String(format: "%.6f, %.6f", point.latitude, point.longitude))
                    .font(TE.mono(.caption2, weight: .regular))
                    .foregroundStyle(TE.textMuted)

                Spacer()

                if let speed = point.speed, speed > 0 {
                    Text(String(format: "%.1f m/s", speed))
                        .font(TE.mono(.caption2, weight: .medium))
                        .foregroundStyle(TE.accent)
                }

                Text("±\(Int(point.horizontalAccuracy))m")
                    .font(TE.mono(.caption2, weight: .regular))
                    .foregroundStyle(TE.textMuted.opacity(0.6))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Permission Request

struct PermissionRequestView: View {
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(TE.accent)

            VStack(spacing: 8) {
                Text("VISIT DETECTION")
                    .font(TE.mono(.caption, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(TE.textPrimary)

                Text("iso.me detects the places you visit and builds a private timeline of your day.")
                    .font(TE.mono(.caption2, weight: .regular))
                    .foregroundStyle(TE.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if locationManager.authorizationStatus == .denied {
                VStack(spacing: 16) {
                    Text("LOCATION ACCESS DENIED")
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(TE.warning)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("OPEN SETTINGS")
                                .font(TE.mono(.caption, weight: .bold))
                                .tracking(1.5)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(TE.accent)
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        locationManager.requestAlwaysAuthorization()
                    } label: {
                        HStack(spacing: 8) {
                            Text("CONTINUE")
                                .font(TE.mono(.caption, weight: .bold))
                                .tracking(1.5)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(TE.accent)
                        )
                    }

                    Text("BACKGROUND VISIT DETECTION REQUIRES THIS")
                        .font(TE.mono(.caption2, weight: .regular))
                        .tracking(0.5)
                        .foregroundStyle(TE.textMuted)
                }
            }

            Spacer()
        }
    }
}

#Preview {
    TodayView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
        locationManager: LocationManager()
    ))
}
