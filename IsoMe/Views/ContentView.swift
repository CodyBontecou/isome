import SwiftUI
import SwiftData
import CoreLocation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LocationViewModel?
    @State private var locationManager: LocationManager?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var crashLog: String?
    @State private var pendingTrackingStart = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                if hasCompletedOnboarding {
                    MainTabView(viewModel: viewModel)
                        .onAppear {
                            if pendingTrackingStart {
                                pendingTrackingStart = false
                                startTrackingFromOnboarding(viewModel: viewModel)
                            }
                        }
                } else {
                    OnboardingView(viewModel: viewModel) { shouldStartTracking in
                        pendingTrackingStart = shouldStartTracking
                        hasCompletedOnboarding = true
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .task {
            if viewModel == nil {
                let manager = LocationManager()
                locationManager = manager
                viewModel = LocationViewModel(
                    modelContext: modelContext,
                    locationManager: manager
                )

                // Migrate existing users: if they already granted permissions or turned
                // tracking on, skip onboarding automatically the first time this version runs.
                if UserDefaults.standard.object(forKey: "hasCompletedOnboarding") == nil {
                    let hasExistingSetup = manager.authorizationStatus != .notDetermined ||
                        UserDefaults.standard.bool(forKey: "isTrackingEnabled") ||
                        UserDefaults.standard.bool(forKey: "isContinuousTrackingEnabled")
                    hasCompletedOnboarding = hasExistingSetup
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
            viewModel?.loadData()
        }
        .onAppear {
            if let log = UserDefaults.standard.string(forKey: "lastCrashLog") {
                crashLog = log
                UserDefaults.standard.removeObject(forKey: "lastCrashLog")
            }
        }
        .alert("Previous Crash Detected", isPresented: Binding(
            get: { crashLog != nil },
            set: { if !$0 { crashLog = nil } }
        )) {
            Button("Copy to Clipboard") {
                UIPasteboard.general.string = crashLog
                crashLog = nil
            }
            Button("Dismiss", role: .cancel) { crashLog = nil }
        } message: {
            Text(crashLog ?? "")
        }
    }

    private func startTrackingFromOnboarding(viewModel: LocationViewModel) {
        let defaults = UserDefaults.standard
        let enableTracking = defaults.object(forKey: "defaultLocationTrackingEnabled") == nil
            ? true
            : defaults.bool(forKey: "defaultLocationTrackingEnabled")
        let enableContinuous = defaults.object(forKey: "defaultContinuousTracking") == nil
            ? true
            : defaults.bool(forKey: "defaultContinuousTracking")

        if enableTracking {
            viewModel.startTracking()
        }
        if enableContinuous {
            viewModel.enableContinuousTracking()
        }
    }
}

private struct MainTabView: View {
    let viewModel: LocationViewModel

    var body: some View {
        TabView {
            TodayView(viewModel: viewModel)
                .tabItem {
                    Label("Data", systemImage: "list.bullet")
                }

            TrackingView(viewModel: viewModel)
                .tabItem {
                    Label("Track", systemImage: "location.fill")
                }

            LocationMapView(viewModel: viewModel)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

private struct OnboardingView: View {
    let viewModel: LocationViewModel
    let onComplete: (Bool) -> Void

    @ObservedObject private var locationManager: LocationManager

    @State private var selectedPage = 0
    @State private var startTrackingWhenDone = false

    @AppStorage("defaultContinuousTracking") private var defaultContinuousTracking = true
    @AppStorage("defaultLocationTrackingEnabled") private var defaultLocationTrackingEnabled = true

    private let pageCount = 4

    init(viewModel: LocationViewModel, onComplete: @escaping (Bool) -> Void) {
        self.viewModel = viewModel
        self.onComplete = onComplete
        _locationManager = ObservedObject(initialValue: viewModel.locationManager)
    }

    var body: some View {
        ZStack {
            OnboardingBackdrop()

            VStack(spacing: 0) {
                pageIndicators
                    .padding(.top, 58)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                TabView(selection: $selectedPage) {
                    welcomePage
                        .tag(0)

                    featuresPage
                        .tag(1)

                    permissionsPage
                        .tag(2)

                    finishPage
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.42, dampingFraction: 0.84), value: selectedPage)

                controls
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 42)
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            guard selectedPage == 2 else { return }
            if newStatus == .authorizedAlways {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedPage = 3
                }
            }
        }
    }

    private var welcomePage: some View {
        LocationOnboardingPageView(
            icon: "",
            eyebrow: "Welcome",
            title: "SPOTTED",
            description: "A calm, private timeline of where your day takes you — always on-device and in your control.",
            useAppIcon: true
        ) {
            VStack(spacing: 10) {
                OnboardingChecklistRow(icon: "mappin.and.ellipse", text: "Auto-detect places you visit")
                OnboardingChecklistRow(icon: "point.topleft.down.to.point.bottomright.curvepath", text: "Capture detailed routes when needed")
                OnboardingChecklistRow(icon: "lock.shield.fill", text: "Keep all location data on-device")
            }
        }
    }

    private var featuresPage: some View {
        LocationOnboardingPageView(
            icon: "square.grid.2x2.fill",
            eyebrow: "Core Features",
            title: "KEY FEATURES",
            description: "Glanceable, battery-aware, and deeply contextual when you need it."
        ) {
            VStack(spacing: 12) {
                OnboardingFeatureCard(
                    icon: "house.and.flag.fill",
                    title: "Visit timeline",
                    description: "Arrivals, durations, and changes throughout your day."
                )

                OnboardingFeatureCard(
                    icon: "map.fill",
                    title: "Path visualization",
                    description: "Routes with start and end markers plus optional detail points."
                )

                OnboardingFeatureCard(
                    icon: "square.and.arrow.up",
                    title: "Flexible exports",
                    description: "JSON, CSV, or Markdown — whenever you need it."
                )
            }
        }
    }

    private var permissionsPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Text("PERMISSION SETUP")
                        .font(.onboardingMicro)
                        .tracking(2.2)
                        .foregroundStyle(OnboardingPalette.textMuted)

                    Text("ALLOW BACKGROUND ACCESS")
                        .font(.onboardingTitle)
                        .tracking(1.2)
                        .foregroundStyle(OnboardingPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("\"Always\" enables background tracking and automatic visit detection.")
                        .font(.onboardingBody)
                        .foregroundStyle(OnboardingPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.top, 12)

                VStack(spacing: 10) {
                    OnboardingStatusRow(
                        title: "Location access",
                        subtitle: locationManager.authorizationStatus.onboardingLabel,
                        icon: locationManager.authorizationStatus.onboardingIcon,
                        color: locationManager.authorizationStatus.onboardingColor
                    )

                    OnboardingStatusRow(
                        title: "Background tracking",
                        subtitle: locationManager.hasAlwaysPermission
                            ? "Ready for always-on visit detection"
                            : "Needs \"Always Allow\" for best results",
                        icon: locationManager.hasAlwaysPermission ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                        color: locationManager.hasAlwaysPermission ? OnboardingPalette.success : OnboardingPalette.warning
                    )
                }

                permissionActionCard
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var permissionActionCard: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            VStack(alignment: .leading, spacing: 12) {
                Text("STEP 1 OF 2")
                    .font(.onboardingMicro)
                    .tracking(1.8)
                    .foregroundStyle(OnboardingPalette.textMuted)

                Text("Start by choosing \"Allow While Using App\" in the system prompt.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    locationManager.requestWhenInUseAuthorization()
                } label: {
                    Label("Allow Location Access", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCard()

        case .authorizedWhenInUse:
            VStack(alignment: .leading, spacing: 12) {
                Text("STEP 2 OF 2")
                    .font(.onboardingMicro)
                    .tracking(1.8)
                    .foregroundStyle(OnboardingPalette.textMuted)

                Text("Upgrade to \"Always Allow\" so visit detection continues when the app is closed.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    locationManager.requestAlwaysAuthorization()
                } label: {
                    Label("Upgrade to Always Allow", systemImage: "arrow.up.forward.app.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCard()

        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 12) {
                Text("LOCATION ACCESS IS OFF")
                    .font(.onboardingMicro)
                    .tracking(1.8)
                    .foregroundStyle(OnboardingPalette.textMuted)

                Text("In iPhone Settings, choose iso.me → Location → Always.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    openSettings()
                } label: {
                    Label("Open iPhone Settings", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OnboardingSecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCard()

        case .authorizedAlways:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(OnboardingPalette.success)

                Text("Perfect — permissions are fully configured.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCard()

        @unknown default:
            EmptyView()
        }
    }

    private var finishPage: some View {
        LocationOnboardingPageView(
            icon: locationManager.hasAlwaysPermission ? "checkmark.seal.fill" : "sparkles",
            eyebrow: "Ready",
            title: "YOU'RE ALL SET",
            description: "Start now, or fine-tune tracking behavior later in Settings."
        ) {
            VStack(spacing: 12) {
                OnboardingSummaryRow(
                    icon: "location.fill",
                    title: "Location permission",
                    value: locationManager.authorizationStatus.onboardingLabel
                )

                OnboardingSummaryRow(
                    icon: "bolt.fill",
                    title: "Default mode",
                    value: defaultContinuousTracking ? "Continuous" : "Visit only"
                )

                OnboardingSummaryRow(
                    icon: "lock.fill",
                    title: "Privacy",
                    value: "Stored on-device"
                )
            }
            .onboardingCard(padding: 14, fill: OnboardingPalette.card)

            if locationManager.hasLocationPermission {
                Toggle(isOn: $startTrackingWhenDone) {
                    Text("Start tracking immediately")
                        .font(.onboardingBody)
                        .fontWeight(.medium)
                        .foregroundStyle(OnboardingPalette.textPrimary)
                }
                .tint(OnboardingPalette.accent)
                .onboardingCard(padding: 14, fill: OnboardingPalette.cardSoft)
            } else {
                Text("You can grant permission later from the Settings tab.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCard(padding: 14, fill: OnboardingPalette.cardSoft)
            }
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index <= selectedPage ? OnboardingPalette.accent : OnboardingPalette.border)
                    .frame(height: 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.88), value: selectedPage)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if selectedPage > 0 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedPage -= 1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("BACK")
                    }
                }
                .buttonStyle(OnboardingTextButtonStyle())
            } else {
                Spacer()
                    .frame(width: 86)
            }

            Spacer()

            Button {
                handlePrimaryAction()
            } label: {
                HStack(spacing: 6) {
                    Text(primaryButtonTitle.uppercased())

                    Image(systemName: selectedPage == pageCount - 1 ? "checkmark" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
        }
    }

    private var primaryButtonTitle: String {
        if selectedPage == pageCount - 1 {
            return String(localized: "Get Started")
        }

        if selectedPage == 2 && locationManager.authorizationStatus == .notDetermined {
            return String(localized: "Skip")
        }

        return String(localized: "Next")
    }

    private func handlePrimaryAction() {
        guard selectedPage < pageCount - 1 else {
            completeOnboarding()
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedPage += 1
        }
    }

    private func completeOnboarding() {
        let shouldStartTracking = startTrackingWhenDone && locationManager.hasLocationPermission
        onComplete(shouldStartTracking)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct LocationOnboardingPageView<AccentContent: View>: View {
    let icon: String
    let eyebrow: String
    let title: String
    let description: String
    var useAppIcon: Bool = false
    @ViewBuilder let accentContent: () -> AccentContent

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 20)

            if useAppIcon,
               let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
               let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primary["CFBundleIconFiles"] as? [String],
               let iconName = iconFiles.last,
               let uiImage = UIImage(named: iconName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 102, height: 102)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                ZStack {
                    Circle()
                        .fill(OnboardingPalette.cardSoft)
                        .frame(width: 102, height: 102)
                        .overlay {
                            Circle()
                                .stroke(OnboardingPalette.border, lineWidth: 1)
                        }

                    Image(systemName: icon)
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(OnboardingPalette.accent)
                }
            }

            VStack(spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(.onboardingMicro)
                    .tracking(2.5)
                    .foregroundStyle(OnboardingPalette.textMuted)

                Text(title)
                    .font(.onboardingDisplay)
                    .tracking(1.4)
                    .foregroundStyle(OnboardingPalette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.onboardingBody)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
            }

            accentContent()
                .frame(maxWidth: .infinity)

            Spacer(minLength: 14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

private struct OnboardingFeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(OnboardingPalette.accent)
                .frame(width: 3, height: 32)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.accent)

                    Text(title)
                        .font(.onboardingHeadline)
                        .foregroundStyle(OnboardingPalette.textPrimary)
                }

                Text(description)
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .onboardingCard(padding: 14, fill: OnboardingPalette.card)
    }
}

private struct OnboardingStatusRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.onboardingHeadline)
                    .foregroundStyle(OnboardingPalette.textPrimary)

                Text(subtitle)
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .onboardingCard(padding: 12, fill: OnboardingPalette.cardSoft)
    }
}

private struct OnboardingSummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingPalette.accent)
                .frame(width: 20)

            Text(title)
                .font(.onboardingCaption)
                .foregroundStyle(OnboardingPalette.textPrimary)

            Spacer()

            Text(value)
                .font(.onboardingMicro)
                .tracking(0.7)
                .foregroundStyle(OnboardingPalette.textSecondary)
        }
    }
}

private struct OnboardingChecklistRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(OnboardingPalette.accent)
                .frame(width: 18)

            Text(text)
                .font(.onboardingCaption)
                .foregroundStyle(OnboardingPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingSignalColumn: View {
    let delay: Double
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(OnboardingPalette.accent.opacity(isAnimating ? (1.0 - Double(index) * 0.17) : 0.25))
                    .frame(width: 5, height: CGFloat(22 - index * 3))
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                isAnimating = true
            }
        }
    }
}

private struct OnboardingBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    OnboardingPalette.backgroundTop,
                    OnboardingPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(OnboardingPalette.accent.opacity(0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 42)
                .offset(x: -130, y: -300)

            Circle()
                .fill(OnboardingPalette.accent.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 38)
                .offset(x: 140, y: 330)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

private struct OnboardingCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var fill: Color = OnboardingPalette.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(OnboardingPalette.border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.03), radius: 9, x: 0, y: 5)
    }
}

private extension View {
    func onboardingCard(padding: CGFloat = 16, fill: Color = OnboardingPalette.card) -> some View {
        modifier(OnboardingCardModifier(padding: padding, fill: fill))
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.onboardingButton)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OnboardingPalette.accent)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(OnboardingPalette.accent.opacity(0.82), lineWidth: 1)
            }
            .shadow(color: OnboardingPalette.accent.opacity(0.24), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.onboardingButton)
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(OnboardingPalette.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(OnboardingPalette.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(OnboardingPalette.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct OnboardingTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.onboardingMicro)
            .tracking(1.3)
            .foregroundStyle(OnboardingPalette.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(OnboardingPalette.card.opacity(configuration.isPressed ? 0.8 : 0.001))
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum OnboardingPalette {
    static let backgroundTop = Color(red: 0.974, green: 0.981, blue: 0.996)
    static let backgroundBottom = Color(red: 0.924, green: 0.942, blue: 0.979)

    static let card = Color.white.opacity(0.94)
    static let cardSoft = Color(red: 0.953, green: 0.966, blue: 0.992)
    static let border = Color(red: 0.816, green: 0.852, blue: 0.917)

    static let accent = Color(red: 0.196, green: 0.455, blue: 0.956)

    static let textPrimary = Color(red: 0.125, green: 0.161, blue: 0.247)
    static let textSecondary = Color(red: 0.294, green: 0.345, blue: 0.459)
    static let textMuted = Color(red: 0.459, green: 0.514, blue: 0.639)

    static let success = Color(red: 0.173, green: 0.67, blue: 0.42)
    static let warning = Color(red: 0.923, green: 0.611, blue: 0.145)
    static let danger = Color(red: 0.849, green: 0.327, blue: 0.278)
}

private extension Font {
    static let onboardingDisplay = Font.system(.largeTitle, design: .monospaced, weight: .semibold)
    static let onboardingTitle = Font.system(.title2, design: .monospaced, weight: .semibold)
    static let onboardingHeadline = Font.system(.headline, design: .monospaced, weight: .semibold)
    static let onboardingBody = Font.system(.body, design: .rounded, weight: .regular)
    static let onboardingCaption = Font.system(.callout, design: .rounded, weight: .regular)
    static let onboardingMicro = Font.system(.footnote, design: .monospaced, weight: .semibold)
    static let onboardingButton = Font.system(.callout, design: .monospaced, weight: .semibold)
}

private extension CLAuthorizationStatus {
    var onboardingLabel: String {
        switch self {
        case .notDetermined:
            return String(localized: "Not requested")
        case .restricted:
            return String(localized: "Restricted")
        case .denied:
            return String(localized: "Denied")
        case .authorizedWhenInUse:
            return String(localized: "While using")
        case .authorizedAlways:
            return String(localized: "Always allowed")
        @unknown default:
            return String(localized: "Unknown")
        }
    }

    var onboardingIcon: String {
        switch self {
        case .authorizedAlways:
            return "checkmark.circle.fill"
        case .authorizedWhenInUse:
            return "clock.badge.checkmark.fill"
        case .denied, .restricted:
            return "xmark.octagon.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    var onboardingColor: Color {
        switch self {
        case .authorizedAlways:
            return OnboardingPalette.success
        case .authorizedWhenInUse:
            return OnboardingPalette.warning
        case .denied, .restricted:
            return OnboardingPalette.danger
        case .notDetermined:
            return OnboardingPalette.textMuted
        @unknown default:
            return OnboardingPalette.textMuted
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Visit.self, LocationPoint.self], inMemory: true)
}
