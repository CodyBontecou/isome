import SwiftUI
import SwiftData

struct TrackingView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @ObservedObject private var usageTracker = UsageTracker.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPaywall = false
    @State private var pulsePhase: CGFloat = 0

    @AppStorage("defaultContinuousTracking") private var defaultContinuousTracking = true
    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true

    private var isLockedOut: Bool {
        usageTracker.hasExceededFreeLimit && !storeManager.isPurchased
    }

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
            ZStack {
                TE.surface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top module label
                    moduleHeader

                    // LCD Display
                    lcdDisplay
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    Spacer()

                    // Control section
                    controlSection
                        .padding(.horizontal, 16)

                    Spacer()

                    // Bottom info bar
                    if !isTracking && !storeManager.isPurchased {
                        usageMeter
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if isContinuousTracking, let remaining = locationManager.continuousTrackingRemainingTime {
                        autoOffIndicator(remaining: remaining)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ISO.ME")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(TE.textMuted)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeManager: storeManager)
            }
        }
    }

    // MARK: - Module Header

    private var moduleHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isTracking ? TE.lcdGreen : TE.textMuted.opacity(0.3))
                .frame(width: 6, height: 6)

            Text(isTracking ? "ACTIVE" : "STANDBY")
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(2)
                .foregroundStyle(isTracking ? TE.textPrimary : TE.textMuted)

            Spacer()

            if isContinuousTracking {
                Text("CONTINUOUS")
                    .font(TE.mono(.caption2, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(TE.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - LCD Display

    private var lcdDisplay: some View {
        VStack(spacing: 0) {
            if isContinuousTracking {
                // Active session display
                TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                    VStack(spacing: 0) {
                        // Duration - big LCD readout
                        HStack(alignment: .firstTextBaseline) {
                            Text(viewModel.formattedSessionTrackingDuration)
                                .font(.system(size: 52, weight: .light, design: .monospaced))
                                .foregroundStyle(TE.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                        Text("ELAPSED")
                            .font(TE.mono(.caption2, weight: .medium))
                            .tracking(2)
                            .foregroundStyle(TE.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.top, 2)

                        Divider()
                            .background(TE.border)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        // Stats row
                        HStack(spacing: 0) {
                            statCell(
                                value: viewModel.formattedSessionDistance,
                                label: "DIST"
                            )

                            Rectangle()
                                .fill(TE.border)
                                .frame(width: 1)
                                .padding(.vertical, 12)

                            statCell(
                                value: "\(viewModel.sessionLocationPoints.count)",
                                label: "PTS"
                            )
                        }
                        .padding(.bottom, 16)
                    }
                }
            } else {
                // Idle display
                VStack(spacing: 12) {
                    Text("--:--:--")
                        .font(.system(size: 52, weight: .light, design: .monospaced))
                        .foregroundStyle(TE.textMuted.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    Text("READY TO TRACK")
                        .font(TE.mono(.caption2, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(TE.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(TE.lcdBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(TE.border, lineWidth: 1)
        )
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(TE.mono(.title3, weight: .medium))
                .foregroundStyle(TE.textPrimary)

            Text(label)
                .font(TE.mono(.caption2, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(TE.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Control Section

    private var controlSection: some View {
        VStack(spacing: 16) {
            // Main action button — rectangular, TE-style
            Button {
                if isLockedOut {
                    showingPaywall = true
                    return
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
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
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isTracking ? TE.danger : TE.accent)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: isTracking ? "stop.fill" : "play.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        )

                    Text(isTracking ? "STOP" : "START")
                        .font(TE.mono(.body, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(isTracking ? TE.danger : TE.textPrimary)

                    Spacer()

                    // Right chevron indicator
                    Image(systemName: isTracking ? "xmark" : "arrow.right")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(TE.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isTracking ? TE.danger.opacity(0.4) : TE.border,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .solid), trigger: isTracking)

            // Mode label
            HStack {
                Text(isContinuousTracking ? "HIGH ACCURACY" : defaultContinuousTracking ? "CONTINUOUS MODE" : "VISIT MODE")
                    .font(TE.mono(.caption2, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(TE.textMuted)

                Spacer()
            }
        }
    }

    // MARK: - Auto-Off Indicator

    private func autoOffIndicator(remaining: TimeInterval) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(TE.textMuted)

            Text("AUTO-OFF  \(formatTime(remaining))")
                .font(TE.mono(.caption2, weight: .medium))
                .tracking(1)
                .foregroundStyle(TE.textMuted)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(TE.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(TE.border, lineWidth: 1)
                )
        )
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)H \(minutes)M"
        } else {
            return "\(minutes) MIN"
        }
    }

    // MARK: - Usage Meter

    private var usageMeter: some View {
        let totalHours = usageTracker.totalUsageHours
        let limitHours = UsageTracker.freeUsageLimitSeconds / 3600
        let progress = min(totalHours / limitHours, 1.0)

        return VStack(spacing: 8) {
            HStack {
                Text("USAGE")
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(TE.textMuted)

                Spacer()

                Text("\(totalHours, specifier: "%.1f") / \(limitHours, specifier: "%.0f") HR")
                    .font(TE.mono(.caption2, weight: .medium))
                    .foregroundStyle(TE.textMuted)
            }

            // Segmented progress bar (TE-style)
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let segmentCount = 20
                let gap: CGFloat = 2
                let segmentWidth = (totalWidth - CGFloat(segmentCount - 1) * gap) / CGFloat(segmentCount)
                let filledSegments = Int(Double(segmentCount) * progress)

                HStack(spacing: gap) {
                    ForEach(0..<segmentCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                index < filledSegments
                                    ? (progress >= 1.0 ? TE.danger : TE.accent)
                                    : TE.border.opacity(0.5)
                            )
                            .frame(width: segmentWidth, height: 8)
                    }
                }
            }
            .frame(height: 8)

            if isLockedOut {
                Button {
                    showingPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Text("UNLOCK")
                            .font(TE.mono(.caption2, weight: .bold))
                            .tracking(1.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(TE.accent)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(TE.border, lineWidth: 1)
                )
        )
    }
}

#Preview {
    TrackingView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
        locationManager: LocationManager()
    ))
}
