import SwiftUI
import SwiftData

struct TrackingView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @State private var pulseAnimation = false
    
    // Default tracking settings
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Status indicator
                statusSection
                
                // Big tracking button
                trackingButton
                
                // Stats when tracking
                if isContinuousTracking {
                    statsSection
                }
                
                Spacer()
                
                // Remaining time indicator
                if isContinuousTracking, let remaining = locationManager.continuousTrackingRemainingTime {
                    autoOffIndicator(remaining: remaining)
                }
            }
            .padding()
            .navigationTitle("Track")
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(spacing: 8) {
            ZStack {
                // Pulsing background when tracking
                if isTracking {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
                
                Image(systemName: isTracking ? "location.fill" : "location")
                    .font(.system(size: 48))
                    .foregroundStyle(isTracking ? .blue : .secondary)
            }
            .frame(height: 100)
            
            Text(isTracking ? "Tracking Active" : "Not Tracking")
                .font(.title2.bold())
                .foregroundStyle(isTracking ? .primary : .secondary)
            
            if isTracking {
                if isContinuousTracking {
                    Text("High-accuracy continuous tracking")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Visit monitoring active")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap the button to start tracking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if isTracking {
                pulseAnimation = true
            }
        }
        .onChange(of: isTracking) { _, newValue in
            pulseAnimation = newValue
        }
    }
    
    // MARK: - Tracking Button
    
    private var trackingButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isTracking {
                    // Stop all tracking
                    if isContinuousTracking {
                        viewModel.disableContinuousTracking()
                    }
                    viewModel.stopTracking()
                } else {
                    // Start tracking based on defaults
                    if defaultLocationTrackingEnabled {
                        viewModel.startTracking()
                    }
                    if defaultContinuousTracking {
                        viewModel.enableContinuousTracking()
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isTracking ? Color.red : Color.blue)
                    .frame(width: 140, height: 140)
                    .shadow(color: (isTracking ? Color.red : Color.blue).opacity(0.4), radius: 12, y: 4)
                
                VStack(spacing: 4) {
                    Image(systemName: isTracking ? "stop.fill" : "play.fill")
                        .font(.system(size: 36))
                    
                    Text(isTracking ? "Stop" : "Start")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .solid), trigger: isTracking)
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text(viewModel.formattedSessionTrackingDuration)
                        .font(.title3.bold().monospacedDigit())
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text(viewModel.formattedSessionDistance)
                        .font(.title3.bold().monospacedDigit())
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 4) {
                    Text("\(viewModel.sessionLocationPoints.count)")
                        .font(.title3.bold().monospacedDigit())
                    Text("Points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Auto-Off Indicator
    
    private func autoOffIndicator(remaining: TimeInterval) -> some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            
            Text("Auto-off in \(formatTime(remaining))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

#Preview {
    TrackingView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
        locationManager: LocationManager()
    ))
}
