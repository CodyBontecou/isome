import SwiftUI
import MapKit

/// A map view that displays a session's recorded path with start/end markers
/// and a gradient polyline showing direction of travel
struct SessionPathMapView: View {
    let points: [LocationPoint]
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        Map(position: $cameraPosition) {
            // Draw path segments with gradient effect
            if points.count >= 2 {
                // Main path polyline
                MapPolyline(coordinates: points.map { $0.coordinate })
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.4), .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 4
                    )
            }
            
            // Start marker (first point)
            if let firstPoint = points.first {
                Annotation("Start", coordinate: firstPoint.coordinate) {
                    StartMarker(
                        accessibilityLabel: "Session path start",
                        accessibilityValue: firstPoint.accessibilityValue
                    )
                }
            }
            
            // End/Current marker (last point)
            if let lastPoint = points.last, points.count > 1 {
                Annotation("Current", coordinate: lastPoint.coordinate) {
                    CurrentLocationMarker(
                        accessibilityLabel: "Session path current location",
                        accessibilityValue: lastPoint.accessibilityValue
                    )
                }
            }
            
            // Intermediate point markers (show every nth point for clarity)
            ForEach(intermediatePoints) { point in
                Annotation("", coordinate: point.coordinate) {
                    Circle()
                        .fill(.blue.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            // Minimal controls for the mini map
        }
        .onChange(of: points.count) { _, _ in
            updateCameraPosition()
        }
        .onAppear {
            updateCameraPosition()
        }
        .accessibilityLabel("Session path map")
        .accessibilityValue(sessionAccessibilitySummary)
    }
    
    /// Returns intermediate points (every 10th point, excluding first and last)
    private var intermediatePoints: [LocationPoint] {
        guard points.count > 2 else { return [] }
        
        let step = max(1, points.count / 10) // Show roughly 10 intermediate markers
        var result: [LocationPoint] = []
        
        for i in stride(from: step, to: points.count - 1, by: step) {
            result.append(points[i])
        }
        
        return result
    }
    
    private func updateCameraPosition() {
        guard !points.isEmpty else { return }
        
        let coordinates = points.map { $0.coordinate }
        let region = MKCoordinateRegion(coordinates: coordinates, padding: 1.3)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            cameraPosition = .region(region)
        }
    }

    private var sessionAccessibilitySummary: String {
        guard let first = points.first else {
            return "No path points."
        }

        var parts = ["\(points.count) \(points.count == 1 ? "point" : "points")"]
        parts.append("Started \(first.accessibilityTimestamp)")

        if let last = points.last, points.count > 1 {
            parts.append("Ended \(last.accessibilityTimestamp)")
            parts.append("Distance \(formattedDistance(totalDistance))")
        }

        return parts.joined(separator: ". ")
    }

    private var totalDistance: Double {
        guard points.count > 1 else { return 0 }
        var distance: Double = 0
        for index in 1..<points.count {
            distance += points[index - 1].distance(to: points[index])
        }
        return distance
    }

    private func formattedDistance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return String(format: "%.1f kilometers", meters / 1_000)
        }
        return String(format: "%.0f meters", meters)
    }
}

// MARK: - Marker Views

struct StartMarker: View {
    var accessibilityLabel = "Path start"
    var accessibilityValue = ""

    var body: some View {
        ZStack {
            Circle()
                .fill(.green)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            
            Image(systemName: "flag.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        .frame(width: 44, height: 44)
        .shadow(color: .green.opacity(0.3), radius: 4, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

struct CurrentLocationMarker: View {
    var accessibilityLabel = "Current location"
    var accessibilityValue = ""
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulse effect
            Circle()
                .fill(.blue.opacity(0.3))
                .frame(width: 32, height: 32)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)
                .accessibilityHidden(true)
            
            Circle()
                .fill(.blue)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
        .frame(width: 44, height: 44)
        .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D], padding: Double = 1.5) {
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
        
        let latDelta = max(0.005, (maxLat - minLat) * padding)
        let lonDelta = max(0.005, (maxLon - minLon) * padding)
        
        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
        
        self = MKCoordinateRegion(center: center, span: span)
    }
}

#Preview {
    SessionPathMapView(points: [
        LocationPoint(latitude: 37.7749, longitude: -122.4194, timestamp: Date().addingTimeInterval(-300), horizontalAccuracy: 5),
        LocationPoint(latitude: 37.7755, longitude: -122.4180, timestamp: Date().addingTimeInterval(-240), horizontalAccuracy: 5),
        LocationPoint(latitude: 37.7760, longitude: -122.4170, timestamp: Date().addingTimeInterval(-180), horizontalAccuracy: 5),
        LocationPoint(latitude: 37.7770, longitude: -122.4160, timestamp: Date().addingTimeInterval(-120), horizontalAccuracy: 5),
        LocationPoint(latitude: 37.7780, longitude: -122.4150, timestamp: Date(), horizontalAccuracy: 5)
    ])
    .frame(height: 300)
}
