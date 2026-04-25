import SwiftUI
import SwiftData
import CoreLocation
import StoreKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LocationViewModel?
    @State private var locationManager: LocationManager?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var crashLog: String?
    @State private var pendingTrackingStart = false
    @State private var pendingActivityPrompt: ActivityStartPromptContext?

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
                        UserDefaults.standard.bool(forKey: TrackingStorageKeys.enabled)
                    hasCompletedOnboarding = hasExistingSetup
                }

                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--show-onboarding") {
                    hasCompletedOnboarding = false
                }
                #endif
            }

            consumePendingActivityPromptIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
            viewModel?.loadData()
            consumePendingActivityPromptIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .activityStartPromptRequested)) { notification in
            if let prompt = ActivityStartPromptContext(userInfo: notification.userInfo ?? [:]) {
                pendingActivityPrompt = prompt
                AppDelegate.pendingActivityPromptUserInfo = nil
                LogManager.shared.info("[Movement] Opened confirmation view for movement prompt: \(prompt.reason).")
            }
        }
        .onAppear {
            if let log = UserDefaults.standard.string(forKey: "lastCrashLog") {
                crashLog = log
                UserDefaults.standard.removeObject(forKey: "lastCrashLog")
            }
            consumePendingActivityPromptIfNeeded()
        }
        .sheet(item: $pendingActivityPrompt) { prompt in
            ActivityStartPromptDecisionView(
                prompt: prompt,
                onStart: {
                    viewModel?.locationManager.confirmActivityStartPrompt(prompt)
                    pendingActivityPrompt = nil
                },
                onNotNow: {
                    viewModel?.locationManager.declineActivityStartPrompt(prompt)
                    pendingActivityPrompt = nil
                }
            )
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
        viewModel.enableTracking()
    }

    private func consumePendingActivityPromptIfNeeded() {
        guard pendingActivityPrompt == nil,
              let userInfo = AppDelegate.pendingActivityPromptUserInfo,
              let prompt = ActivityStartPromptContext(userInfo: userInfo) else {
            return
        }

        pendingActivityPrompt = prompt
        AppDelegate.pendingActivityPromptUserInfo = nil
        LogManager.shared.info("[Movement] Restored pending movement prompt after app launch.")
    }
}

private struct ActivityStartPromptDecisionView: View {
    let prompt: ActivityStartPromptContext
    let onStart: () -> Void
    let onNotNow: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("MOVEMENT DETECTED")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(TE.textMuted)

                    Text(prompt.reason.capitalized)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TE.textPrimary)

                    Text("Start tracking now?")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TE.textMuted)
                }

                VStack(spacing: 10) {
                    Button {
                        onStart()
                        dismiss()
                    } label: {
                        Text("START RECORDING")
                            .font(TE.mono(.caption, weight: .semibold))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TE.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundStyle(Color.white)
                    }

                    Button {
                        onNotNow()
                        dismiss()
                    } label: {
                        Text("NOT NOW")
                            .font(TE.mono(.caption, weight: .semibold))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TE.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(TE.border, lineWidth: 1)
                            }
                            .foregroundStyle(TE.textPrimary)
                    }
                }
            }
            .padding(20)
            .navigationTitle("Start Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        onNotNow()
                        dismiss()
                    }
                    .font(TE.mono(.caption2, weight: .medium))
                    .foregroundStyle(TE.textMuted)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct MainTabView: View {
    let viewModel: LocationViewModel
    @State private var selectedTab: Int = MainTabView.initialTabFromLaunchArguments()

    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineView(viewModel: viewModel)
                .tabItem {
                    Label("Timeline", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(0)

            LocationMapView(viewModel: viewModel)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(1)

            InsightsView(viewModel: viewModel)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
    }

    private static func initialTabFromLaunchArguments() -> Int {
        #if DEBUG
        let prefix = "--default-tab="
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
           let index = Int(arg.dropFirst(prefix.count)),
           (0...3).contains(index) {
            return index
        }
        #endif
        return 0
    }
}

// MARK: - Onboarding

private struct OnboardingView: View {
    let viewModel: LocationViewModel
    let onComplete: (Bool) -> Void

    @ObservedObject private var locationManager: LocationManager
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var selectedPage: Int
    @State private var selectedPlan: StoreManager.Plan = .yearly
    private let pageCount = 5
    private var paywallPageIndex: Int { pageCount - 1 }
    private var permissionsPageIndex: Int { 2 }

    init(viewModel: LocationViewModel, onComplete: @escaping (Bool) -> Void) {
        self.viewModel = viewModel
        self.onComplete = onComplete
        _locationManager = ObservedObject(initialValue: viewModel.locationManager)
        _selectedPage = State(initialValue: Self.initialPageFromLaunchArguments())
    }

    private static func initialPageFromLaunchArguments() -> Int {
        #if DEBUG
        let prefix = "--onboarding-page="
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }),
           let index = Int(arg.dropFirst(prefix.count)),
           (0...4).contains(index) {
            return index
        }
        #endif
        return 0
    }

    var body: some View {
        ZStack {
            OnboardingBG()

            VStack(spacing: 0) {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeOut(duration: 0.25), value: selectedPage)

                if selectedPage != paywallPageIndex {
                    OnboardingFooter(
                        selectedPage: selectedPage,
                        pageCount: pageCount,
                        primaryTitle: primaryButtonTitle,
                        secondaryTitle: secondaryButtonTitle,
                        onPrimary: handlePrimary,
                        onSecondary: handleSecondary
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            guard selectedPage == permissionsPageIndex else { return }
            if newStatus == .authorizedAlways {
                advance()
            }
        }
        .onChange(of: storeManager.isPurchased) { _, newValue in
            guard selectedPage == paywallPageIndex, newValue else { return }
            finish()
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case 0:
            OnboardingWelcomePage()
        case 1:
            OnboardingPrivatePage()
        case 2:
            OnboardingPermissionsPage(authorizationStatus: locationManager.authorizationStatus)
        case 3:
            OnboardingExportPage()
        default:
            OnboardingPaywallPage(
                storeManager: storeManager,
                selectedPlan: $selectedPlan,
                onStartTrial: handleStartTrial,
                onContinueFree: finish,
                onRestore: handleRestore
            )
        }
    }

    private var primaryButtonTitle: LocalizedStringKey {
        switch selectedPage {
        case permissionsPageIndex:
            switch locationManager.authorizationStatus {
            case .notDetermined, .authorizedWhenInUse:
                return "Enable location"
            case .denied, .restricted:
                return "Open Settings"
            case .authorizedAlways:
                return "Continue"
            @unknown default:
                return "Continue"
            }
        default:
            return "Continue"
        }
    }

    private var secondaryButtonTitle: LocalizedStringKey? {
        selectedPage == 0 ? nil : "Back"
    }

    private func handlePrimary() {
        switch selectedPage {
        case permissionsPageIndex:
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse:
                locationManager.requestAlwaysAuthorization()
            case .denied, .restricted:
                openSystemSettings()
            case .authorizedAlways:
                advance()
            @unknown default:
                advance()
            }
        default:
            advance()
        }
    }

    private func handleStartTrial() {
        Task { await storeManager.purchase(plan: selectedPlan) }
    }

    private func handleRestore() {
        Task {
            await storeManager.restorePurchases()
            if storeManager.isPurchased {
                finish()
            }
        }
    }

    private func handleSecondary() {
        retreat()
    }

    private func advance() {
        guard selectedPage < pageCount - 1 else { finish(); return }
        withAnimation(.easeOut(duration: 0.28)) {
            selectedPage += 1
        }
    }

    private func retreat() {
        guard selectedPage > 0 else { return }
        withAnimation(.easeOut(duration: 0.28)) {
            selectedPage -= 1
        }
    }

    private func finish() {
        let shouldStartTracking = locationManager.hasLocationPermission
        onComplete(shouldStartTracking)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Onboarding sub-components

private struct OnboardingFooter: View {
    let selectedPage: Int
    let pageCount: Int
    let primaryTitle: LocalizedStringKey
    let secondaryTitle: LocalizedStringKey?
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == selectedPage ? OnboardPalette.brandPurple : OnboardPalette.dotInactive)
                        .frame(width: index == selectedPage ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: selectedPage)
                }
            }
            .padding(.bottom, 4)

            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.541, green: 0.510, blue: 0.945),
                                        Color(red: 0.451, green: 0.435, blue: 0.918)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: OnboardPalette.brandPurple.opacity(0.32), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(OnboardPressedScaleStyle())

            if let secondaryTitle {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OnboardPalette.brandPurple)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct OnboardPressedScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Onboarding pages

private struct OnboardingWelcomePage: View {
    var body: some View {
        OnboardingPageScaffold(
            heroImageName: "OnboardingHeroWelcome",
            title: AnyView(
                HStack(spacing: 0) {
                    Text("Welcome to iso")
                    Text(".").foregroundStyle(OnboardPalette.brandRed)
                    Text("me")
                }
            ),
            subtitle: "Your private location timeline,\nbeautifully organized.",
            rows: [
                OnboardingRowSpec(
                    icon: "mappin.and.ellipse",
                    iconBg: OnboardPalette.tilePurple,
                    iconFg: OnboardPalette.iconPurple,
                    title: "Auto-detect places",
                    body: "iso.me finds the places you visit in the background."
                ),
                OnboardingRowSpec(
                    icon: "point.topleft.down.to.point.bottomright.curvepath",
                    iconBg: OnboardPalette.tileGreen,
                    iconFg: OnboardPalette.iconGreen,
                    title: "See exact routes",
                    body: "View the precise GPS routes you take."
                ),
                OnboardingRowSpec(
                    icon: "icloud.and.arrow.up",
                    iconBg: OnboardPalette.tilePeach,
                    iconFg: OnboardPalette.iconPeach,
                    title: "Export anytime",
                    body: "Download your full history in JSON, CSV, or Markdown."
                )
            ]
        )
    }
}

private struct OnboardingPrivatePage: View {
    var body: some View {
        OnboardingPageScaffold(
            heroImageName: "OnboardingHeroPrivate",
            title: AnyView(Text("Private by default")),
            subtitle: "Your places stay yours. iso.me keeps your history protected and easy to control.",
            rows: [
                OnboardingRowSpec(
                    icon: "lock.fill",
                    iconBg: OnboardPalette.tilePeach,
                    iconFg: OnboardPalette.iconPeach,
                    title: "Stored on your device",
                    body: "Your data is saved locally — only on your device."
                ),
                OnboardingRowSpec(
                    icon: "person.crop.circle.badge.checkmark",
                    iconBg: OnboardPalette.tileGreen,
                    iconFg: OnboardPalette.iconGreen,
                    title: "No account required",
                    body: "Use iso.me instantly. No sign up, no personal info."
                ),
                OnboardingRowSpec(
                    icon: "square.and.arrow.up",
                    iconBg: OnboardPalette.tilePurple,
                    iconFg: OnboardPalette.iconPurple,
                    title: "Export when you want",
                    body: "Take your data anytime in JSON, CSV, or Markdown."
                )
            ]
        )
    }
}

private struct OnboardingPermissionsPage: View {
    let authorizationStatus: CLAuthorizationStatus

    var body: some View {
        OnboardingPageScaffold(
            heroImageName: "OnboardingHeroLocation",
            title: AnyView(Text("Auto-detect every visit")),
            subtitle: "To build your private timeline,\nallow location access in the background.",
            rows: permissionRows,
            footer: AnyView(
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OnboardPalette.textMuted)
                    Text("You can change this anytime in Settings.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OnboardPalette.textMuted)
                }
                .padding(.top, 4)
            )
        )
    }

    private var permissionRows: [OnboardingRowSpec] {
        let alwaysGranted = authorizationStatus == .authorizedAlways
        let whenInUse = authorizationStatus == .authorizedWhenInUse
        let denied = authorizationStatus == .denied || authorizationStatus == .restricted

        let locationValue: LocalizedStringKey
        let preciseValue: LocalizedStringKey
        if alwaysGranted {
            locationValue = "Always Allow"
            preciseValue = "On"
        } else if whenInUse {
            locationValue = "While Using"
            preciseValue = "On"
        } else if denied {
            locationValue = "Denied"
            preciseValue = "Off"
        } else {
            locationValue = "Required"
            preciseValue = "Required"
        }

        return [
            OnboardingRowSpec(
                icon: "location.fill",
                iconBg: OnboardPalette.tilePurple,
                iconFg: OnboardPalette.iconPurple,
                title: "Location Access",
                body: locationValue,
                trailing: alwaysGranted ? .check : (denied ? .warn : .none)
            ),
            OnboardingRowSpec(
                icon: "scope",
                iconBg: OnboardPalette.tileGreen,
                iconFg: OnboardPalette.iconGreen,
                title: "Precise Location",
                body: preciseValue,
                trailing: (alwaysGranted || whenInUse) ? .check : (denied ? .warn : .none)
            )
        ]
    }
}

private struct OnboardingExportPage: View {
    var body: some View {
        OnboardingPageScaffold(
            heroImageName: "OnboardingHeroExport",
            title: AnyView(Text("Take your history anywhere")),
            subtitle: "Export your visits and exact routes in clean, portable formats whenever you need them.",
            rows: [
                OnboardingRowSpec(
                    icon: "curlybraces",
                    iconBg: OnboardPalette.tilePurple,
                    iconFg: OnboardPalette.iconPurple,
                    title: "JSON",
                    body: "For developers"
                ),
                OnboardingRowSpec(
                    icon: "tablecells",
                    iconBg: OnboardPalette.tileGreen,
                    iconFg: OnboardPalette.iconGreen,
                    title: "CSV",
                    body: "For spreadsheets"
                ),
                OnboardingRowSpec(
                    icon: "doc.richtext",
                    iconBg: OnboardPalette.tilePeach,
                    iconFg: OnboardPalette.iconPeach,
                    title: "Markdown",
                    body: "For notes & docs"
                )
            ],
            footer: AnyView(
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(OnboardPalette.tilePeach)
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(OnboardPalette.iconPeach)
                    }
                    Text("Ready to track privately from day one.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardPalette.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.66))
                )
                .padding(.top, 10)
            )
        )
    }
}

// MARK: - Onboarding paywall page

private struct OnboardingPaywallPage: View {
    @ObservedObject var storeManager: StoreManager
    @Binding var selectedPlan: StoreManager.Plan
    let onStartTrial: () -> Void
    let onContinueFree: () -> Void
    let onRestore: () -> Void

    private let termsURL = URL(string: "https://iso.me/terms")
    private let privacyURL = URL(string: "https://iso.me/privacy")

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = max(120, min(170, proxy.size.height * 0.20))

            VStack(spacing: 12) {
                Image("OnboardingHeroPaywall")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    Text("Unlock unlimited history")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(OnboardPalette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    Text("Save more places, export anytime, and keep every route beautifully organized.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OnboardPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                }

                OnboardingFeatureCard(rows: featureRows)
                    .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    ForEach(StoreManager.Plan.allCases) { plan in
                        OnboardingPlanCard(
                            plan: plan,
                            product: storeManager.product(for: plan),
                            isSelected: selectedPlan == plan
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) {
                                selectedPlan = plan
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OnboardPalette.brandPurple)
                    Text("7-day free trial on yearly")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OnboardPalette.brandPurple)
                }

                VStack(spacing: 8) {
                    Button(action: onStartTrial) {
                        Group {
                            if storeManager.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(primaryTitle)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.541, green: 0.510, blue: 0.945),
                                            Color(red: 0.451, green: 0.435, blue: 0.918)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: OnboardPalette.brandPurple.opacity(0.28), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(OnboardPressedScaleStyle())
                    .disabled(storeManager.isLoading)

                    Button(action: onContinueFree) {
                        Text("Continue with Free")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardPalette.brandPurple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                            )
                    }
                    .buttonStyle(OnboardPressedScaleStyle())
                    .disabled(storeManager.isLoading)
                }
                .padding(.horizontal, 24)

                if let error = storeManager.purchaseError {
                    Text(error)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(OnboardPalette.brandRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                HStack {
                    Button(action: onRestore) {
                        Text("Restore Purchase")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(OnboardPalette.textMuted)
                    }
                    .disabled(storeManager.isLoading)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        if let termsURL {
                            Link("Terms", destination: termsURL)
                        } else {
                            Text("Terms")
                        }
                        Text("·")
                        if let privacyURL {
                            Link("Privacy", destination: privacyURL)
                        } else {
                            Text("Privacy")
                        }
                    }
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(OnboardPalette.textMuted)
                }
                .padding(.horizontal, 24)
                .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private var primaryTitle: LocalizedStringKey {
        selectedPlan == .yearly ? "Start free trial" : "Continue"
    }

    private var featureRows: [OnboardingRowSpec] {
        [
            OnboardingRowSpec(
                icon: "infinity",
                iconBg: OnboardPalette.tilePurple,
                iconFg: OnboardPalette.iconPurple,
                title: "Unlimited visits & routes"
            ),
            OnboardingRowSpec(
                icon: "doc.text",
                iconBg: OnboardPalette.tileGreen,
                iconFg: OnboardPalette.iconGreen,
                title: "JSON, CSV & Markdown exports"
            ),
            OnboardingRowSpec(
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                iconBg: OnboardPalette.tilePeach,
                iconFg: OnboardPalette.iconPeach,
                title: "Advanced route history"
            ),
            OnboardingRowSpec(
                icon: "checkmark.shield.fill",
                iconBg: OnboardPalette.tilePurple,
                iconFg: OnboardPalette.iconPurple,
                title: "Privacy-first by default"
            )
        ]
    }
}

private struct OnboardingPlanCard: View {
    let plan: StoreManager.Plan
    let product: Product?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? OnboardPalette.brandPurple : OnboardPalette.divider,
                            lineWidth: isSelected ? 5 : 1.5
                        )
                        .frame(width: 18, height: 18)

                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(planTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(OnboardPalette.textPrimary)

                if plan == .yearly {
                    Text("Best value")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(OnboardPalette.brandPurple)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(OnboardPalette.tilePurple)
                        )
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(priceText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(OnboardPalette.textPrimary)
                    Text(priceSuffix)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(OnboardPalette.textMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? OnboardPalette.brandPurple : Color.black.opacity(0.04),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var planTitle: LocalizedStringKey {
        switch plan {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    private var priceText: String {
        if let product { return product.displayPrice }
        switch plan {
        case .monthly: return "$4.99"
        case .yearly: return "$29.99"
        case .lifetime: return "$59.99"
        }
    }

    private var priceSuffix: LocalizedStringKey {
        switch plan {
        case .monthly: return "/ month"
        case .yearly: return "/ year"
        case .lifetime: return "once"
        }
    }
}

// MARK: - Onboarding scaffold

private struct OnboardingPageScaffold: View {
    let heroImageName: String
    let title: AnyView
    let subtitle: LocalizedStringKey
    let rows: [OnboardingRowSpec]
    var footer: AnyView? = nil

    var body: some View {
        GeometryReader { proxy in
            let heroHeight = max(140, min(200, proxy.size.height * 0.27))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    Image(heroImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: heroHeight)
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        title
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(OnboardPalette.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        Text(subtitle)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(OnboardPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 28)
                    }

                    OnboardingFeatureCard(rows: rows)
                        .padding(.horizontal, 24)
                        .padding(.top, 2)

                    if let footer {
                        footer
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 4)
                }
                .padding(.bottom, 6)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
    }
}

private enum OnboardingRowTrailing {
    case none
    case check
    case warn
    case chevron
}

private struct OnboardingRowSpec {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: LocalizedStringKey
    let body: LocalizedStringKey?
    var trailing: OnboardingRowTrailing = .none

    init(
        icon: String,
        iconBg: Color,
        iconFg: Color,
        title: LocalizedStringKey,
        body: LocalizedStringKey? = nil,
        trailing: OnboardingRowTrailing = .none
    ) {
        self.icon = icon
        self.iconBg = iconBg
        self.iconFg = iconFg
        self.title = title
        self.body = body
        self.trailing = trailing
    }
}

private struct OnboardingFeatureCard: View {
    let rows: [OnboardingRowSpec]

    private var compact: Bool { rows.allSatisfy { $0.body == nil } }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                OnboardingFeatureRow(spec: row)
                    .padding(.horizontal, 14)
                    .padding(.vertical, compact ? 6 : 12)

                if index < rows.count - 1 {
                    Rectangle()
                        .fill(OnboardPalette.divider)
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)
    }
}

private struct OnboardingFeatureRow: View {
    let spec: OnboardingRowSpec

    var body: some View {
        HStack(alignment: spec.body == nil ? .center : .top, spacing: spec.body == nil ? 10 : 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(spec.iconBg)
                    .frame(width: spec.body == nil ? 30 : 44, height: spec.body == nil ? 30 : 44)

                Image(systemName: spec.icon)
                    .font(.system(size: spec.body == nil ? 14 : 19, weight: .semibold))
                    .foregroundStyle(spec.iconFg)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(spec.title)
                    .font(.system(size: spec.body == nil ? 14 : 16, weight: .bold))
                    .foregroundStyle(OnboardPalette.textPrimary)

                if let body = spec.body {
                    Text(body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OnboardPalette.textSecondary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch spec.trailing {
            case .none:
                EmptyView()
            case .check:
                ZStack {
                    Circle().fill(OnboardPalette.iconGreen).frame(width: 26, height: 26)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 8)
            case .warn:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(OnboardPalette.brandRed)
                    .padding(.top, 8)
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OnboardPalette.textMuted)
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - Onboarding background & palette

private struct OnboardingBG: View {
    var body: some View {
        ZStack {
            OnboardPalette.background
                .ignoresSafeArea()

            // Soft pastel corner blobs
            Circle()
                .fill(OnboardPalette.blobPeach)
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: 160, y: -340)

            Circle()
                .fill(OnboardPalette.blobLavender)
                .frame(width: 220, height: 220)
                .blur(radius: 36)
                .offset(x: -180, y: 360)

            Circle()
                .fill(OnboardPalette.blobPink)
                .frame(width: 240, height: 240)
                .blur(radius: 38)
                .offset(x: 180, y: 380)

            // Sparkles
            ForEach(0..<6, id: \.self) { i in
                let positions: [CGSize] = [
                    CGSize(width: -130, height: -260),
                    CGSize(width: 140, height: -180),
                    CGSize(width: -160, height: 60),
                    CGSize(width: 150, height: 120),
                    CGSize(width: -110, height: 280),
                    CGSize(width: 130, height: 320)
                ]
                let sizes: [CGFloat] = [10, 14, 8, 12, 9, 11]
                Image(systemName: "sparkle")
                    .font(.system(size: sizes[i], weight: .semibold))
                    .foregroundStyle(OnboardPalette.sparkle)
                    .offset(positions[i])
                    .opacity(0.55)
            }
        }
        .allowsHitTesting(false)
    }
}

private enum OnboardPalette {
    // Base
    static let background = Color(red: 253/255, green: 248/255, blue: 245/255)
    static let textPrimary = Color(red: 0.118, green: 0.149, blue: 0.282)
    static let textSecondary = Color(red: 0.353, green: 0.392, blue: 0.502)
    static let textMuted = Color(red: 0.541, green: 0.580, blue: 0.671)
    static let divider = Color(red: 0.918, green: 0.918, blue: 0.945)

    // Brand
    static let brandPurple = Color(red: 0.482, green: 0.467, blue: 0.929)
    static let brandRed = Color(red: 0.929, green: 0.302, blue: 0.310)

    // Tile fills
    static let tilePurple = Color(red: 0.910, green: 0.890, blue: 0.984)
    static let tileGreen  = Color(red: 0.847, green: 0.929, blue: 0.875)
    static let tilePeach  = Color(red: 0.992, green: 0.875, blue: 0.835)

    // Tile foregrounds
    static let iconPurple = Color(red: 0.482, green: 0.420, blue: 0.882)
    static let iconGreen  = Color(red: 0.298, green: 0.667, blue: 0.467)
    static let iconPeach  = Color(red: 0.929, green: 0.510, blue: 0.388)

    // Decoration
    static let blobPeach    = Color(red: 0.984, green: 0.831, blue: 0.776).opacity(0.45)
    static let blobLavender = Color(red: 0.835, green: 0.808, blue: 0.957).opacity(0.55)
    static let blobPink     = Color(red: 0.973, green: 0.812, blue: 0.847).opacity(0.50)
    static let sparkle      = Color(red: 0.808, green: 0.741, blue: 0.918)

    static let dotInactive = Color(red: 0.808, green: 0.808, blue: 0.831)
}

#Preview {
    ContentView()
        .modelContainer(for: [Visit.self, LocationPoint.self], inMemory: true)
}
