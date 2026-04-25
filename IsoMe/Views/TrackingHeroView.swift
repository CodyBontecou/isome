import SwiftUI
import CoreLocation

/// Mascot + status hero shown on the Timeline tab when there are no entries today.
/// Three states are derived from LocationManager: permission needed, off, on.
struct TrackingHeroView: View {
    @ObservedObject var locationManager: LocationManager

    private enum HeroState {
        case permissionNeeded, off, on
    }

    private var state: HeroState {
        if !locationManager.hasLocationPermission { return .permissionNeeded }
        return locationManager.isTrackingEnabled ? .on : .off
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: DS.Spacing.lg)

            MascotIllustration()

            VStack(spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(headline)
                        .font(DS.Font.title())
                        .foregroundStyle(DS.Color.textPrimary)
                    if state == .on { StatusDot(state: .on) }
                }
                Text(subhead)
                    .font(DS.Font.body())
                    .foregroundStyle(DS.Color.textMuted)
                    .multilineTextAlignment(.center)
            }

            switch state {
            case .permissionNeeded:
                PrimaryButton(title: "Enable location") {
                    locationManager.requestAlwaysAuthorization()
                }
                .padding(.horizontal, DS.Spacing.xl)
            case .off:
                CircularToggle(isOn: false) {
                    locationManager.enableTracking()
                }
                Text("Start Tracking")
                    .font(DS.Font.headline())
                    .foregroundStyle(DS.Color.accentGreen)
            case .on:
                CircularToggle(isOn: true) {
                    locationManager.disableTracking()
                }
                Text("Stop Tracking")
                    .font(DS.Font.headline())
                    .foregroundStyle(DS.Color.accentGreen)
            }

            AccuracyFooter(location: locationManager.currentLocation)
                .padding(.horizontal, DS.Spacing.xl)

            Spacer(minLength: DS.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    private var headline: String {
        switch state {
        case .permissionNeeded: return "Location access needed"
        case .off: return "Tracking is Off"
        case .on: return "Tracking is On"
        }
    }

    private var subhead: String {
        switch state {
        case .permissionNeeded: return "Grant Always-Allow access to detect places automatically."
        case .off: return "Start tracking to record visits and routes for the day."
        case .on: return "Auto-detecting places\nin the background"
        }
    }
}

// MARK: - Mascot

private struct MascotIllustration: View {
    var body: some View {
        ZStack {
            // Soft halo
            Circle()
                .fill(DS.Color.tilePurple.opacity(0.6))
                .frame(width: 220, height: 220)
                .blur(radius: 18)

            // Mascot art if present, else SF Symbol fallback
            if UIImage(named: "Mascot") != nil {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            } else {
                ZStack {
                    Circle()
                        .fill(DS.Color.tilePurple)
                        .frame(width: 180, height: 180)
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(DS.Color.iconPurple)
                }
            }
        }
    }
}

// MARK: - Big circular start/stop button

private struct CircularToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(DS.Color.accentGreen, lineWidth: 4)
                    .frame(width: 96, height: 96)

                if isOn {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(DS.Color.accentGreen)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DS.Color.accentGreen)
                        .offset(x: 3)
                }
            }
            .frame(width: 110, height: 110)
            .background(
                Circle().fill(DS.Color.card)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Stop tracking" : "Start tracking")
    }
}

// MARK: - Accuracy footer

private struct AccuracyFooter: View {
    let location: CLLocation?

    private var accuracyLabel: String {
        guard let location, location.horizontalAccuracy >= 0 else { return "Awaiting fix" }
        if location.horizontalAccuracy <= 20 { return "High Accuracy" }
        if location.horizontalAccuracy <= 100 { return "Medium Accuracy" }
        return "Low Accuracy"
    }

    var body: some View {
        DSCard(padding: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                CategoryIcon(symbol: "location.fill", palette: .green, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(accuracyLabel)
                        .font(DS.Font.body(.semibold))
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("GPS · Wi-Fi · Cell · Motion")
                        .font(DS.Font.caption())
                        .foregroundStyle(DS.Color.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Color.textMuted)
            }
        }
    }
}
