import SwiftUI
import SwiftData

struct TrackingView: View {
    @Bindable var viewModel: LocationViewModel
    @ObservedObject private var locationManager: LocationManager
    @ObservedObject private var usageTracker = UsageTracker.shared
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingPaywall = false
    @State private var pulseOpacity: Double = 1.0

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

                VStack(spacing: 16) {
                    heroCard
                        .frame(maxHeight: .infinity)

                    VStack(spacing: 10) {
                        if isContinuousTracking,
                           let remaining = locationManager.continuousTrackingRemainingTime {
                            autoOffCapsule(remaining: remaining)
                        }

                        if !isTracking && !storeManager.isPurchased {
                            usageCapsule
                        }

                        primaryButton

                        Text(modeLabel)
                            .font(TE.mono(.caption2, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(TE.textMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
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
            .onReceive(NotificationCenter.default.publisher(for: .freeLimitReached)) { _ in
                showingPaywall = true
            }
            .onAppear { pulseOpacity = 0.35 }
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        TECard {
            VStack(alignment: .leading, spacing: 0) {
                statusRow
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                Spacer(minLength: 24)

                timeBlock
                    .padding(.horizontal, 20)

                Spacer(minLength: 24)

                Divider()
                    .background(TE.border)

                statRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isTracking)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isTracking ? TE.accent : TE.textMuted.opacity(0.3))
                .frame(width: 7, height: 7)
                .opacity(isTracking ? pulseOpacity : 1.0)
                .animation(
                    isTracking
                        ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseOpacity
                )

            Text(isTracking ? "TRACKING" : "STANDBY")
                .font(TE.mono(.caption2, weight: .semibold))
                .tracking(2)
                .foregroundStyle(isTracking ? TE.textPrimary : TE.textMuted)

            Spacer()

            if isContinuousTracking {
                Text("CONTINUOUS")
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(TE.accent)
            }
        }
    }

    private var timeBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if isContinuousTracking {
                    TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                        Text(viewModel.formattedSessionTrackingDuration)
                            .font(.system(size: 72, weight: .light, design: .monospaced))
                            .foregroundStyle(TE.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                } else {
                    Text("--:--:--")
                        .font(.system(size: 72, weight: .light, design: .monospaced))
                        .foregroundStyle(TE.textMuted.opacity(0.4))
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(isTracking ? "ELAPSED" : "READY TO TRACK")
                .font(TE.mono(.caption2, weight: .medium))
                .tracking(2)
                .foregroundStyle(TE.textMuted)
        }
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            statCell(value: viewModel.formattedSessionDistance, label: "DIST")
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(TE.border)
                        .frame(width: 1)
                        .padding(.vertical, 10)
                }

            statCell(value: "\(viewModel.sessionLocationPoints.count)", label: "PTS")
        }
    }

    private func statCell(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(TE.mono(.title3, weight: .medium))
                .foregroundStyle(TE.textPrimary)
                .monospacedDigit()

            Text(label)
                .font(TE.mono(.caption2, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(TE.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button {
            handleButtonTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isTracking ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(isTracking ? "STOP" : "START")
                    .font(TE.mono(.body, weight: .bold))
                    .tracking(2.5)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isTracking ? TE.danger : TE.accent)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .solid), trigger: isTracking)
    }

    private var modeLabel: LocalizedStringKey {
        if isContinuousTracking { return "HIGH ACCURACY" }
        if defaultContinuousTracking { return "CONTINUOUS MODE" }
        return "VISIT MODE"
    }

    private func handleButtonTap() {
        if isLockedOut {
            showingPaywall = true
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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

    // MARK: - Capsules

    private func autoOffCapsule(remaining: TimeInterval) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TE.textMuted)

            Text("AUTO-OFF  \(formatTime(remaining))")
                .font(TE.mono(.caption2, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(TE.textMuted)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(TE.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(TE.border, lineWidth: 1)
                )
        )
    }

    private var usageCapsule: some View {
        let totalHours = usageTracker.totalUsageHours
        let limitHours = UsageTracker.freeUsageLimitSeconds / 3600
        let progress = min(totalHours / limitHours, 1.0)

        return Button {
            if isLockedOut { showingPaywall = true }
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Text("USAGE")
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(TE.textMuted)

                    Spacer()

                    Text("\(totalHours, specifier: "%.1f") / \(limitHours, specifier: "%.0f") HR")
                        .font(TE.mono(.caption2, weight: .medium))
                        .tracking(1)
                        .foregroundStyle(TE.textMuted)
                }

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
                                .frame(width: segmentWidth, height: 6)
                        }
                    }
                }
                .frame(height: 6)

                if isLockedOut {
                    HStack(spacing: 4) {
                        Spacer()
                        Text("UNLOCK")
                            .font(TE.mono(.caption2, weight: .bold))
                            .tracking(1.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(TE.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(TE.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(TE.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 { return "\(hours)H \(minutes)M" }
        return "\(minutes) MIN"
    }
}

#Preview {
    TrackingView(viewModel: LocationViewModel(
        modelContext: try! ModelContainer(for: Visit.self, LocationPoint.self).mainContext,
        locationManager: LocationManager()
    ))
}
