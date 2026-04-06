import SwiftUI
import SwiftData
import MapKit

struct TodayView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var selectedPoint: LocationPoint?

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
            .navigationTitle("All Points")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
        }
    }

    private var pointsList: some View {
        List {
            ForEach(viewModel.locationPoints.reversed()) { point in
                LocationPointRow(point: point)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPoint = point
                    }
            }
        }
        .listStyle(.plain)
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

            Text("Location Tracker needs access to your location to record the places you visit throughout the day.")
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
        modelContext: try! ModelContainer(for: Visit.self).mainContext,
        locationManager: LocationManager()
    ))
}
