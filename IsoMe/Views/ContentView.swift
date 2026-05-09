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

                // Wire up services that need the LocationManager
                WebhookManager.shared.attach(
                    modelContainer: modelContext.container,
                    locationManager: manager
                )

                // Migrate existing users: if they already granted permissions or turned
                // tracking on, skip onboarding automatically the first time this version runs.
                if UserDefaults.standard.object(forKey: "hasCompletedOnboarding") == nil {
                    let hasExistingSetup = manager.authorizationStatus != .notDetermined ||
                        UserDefaults.standard.bool(forKey: "isTrackingEnabled")
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
        viewModel.startTracking()
    }
}

private struct MainTabView: View {
    let viewModel: LocationViewModel
    @State private var selectedTab: Int = MainTabView.initialTabFromLaunchArguments()

    var body: some View {
        TabView(selection: $selectedTab) {
            LocationMapView(viewModel: viewModel)
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(0)

            TripListView(viewModel: viewModel)
                .tabItem {
                    Label("Trips", systemImage: "list.bullet")
                }
                .tag(1)

            ExportView(viewModel: viewModel)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .tag(2)

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
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

private struct TripListView: View {
    @Bindable var viewModel: LocationViewModel
    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<UUID>()
    @State private var bulkSubPurpose = ""

    private var selectedVisits: [Visit] {
        viewModel.allVisits.filter { selection.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                if viewModel.allVisits.isEmpty {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                        description: Text("Tracked visits will appear here.")
                    )
                } else {
                    List(selection: $selection) {
                        ForEach(groupedVisits, id: \.day) { group in
                            Section(group.title) {
                                ForEach(group.visits) { visit in
                                    NavigationLink {
                                        VisitDetailView(visit: visit, viewModel: viewModel)
                                    } label: {
                                        TripListRow(visit: visit)
                                    }
                                    .tag(visit.id)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            classify(visit, as: .business)
                                        } label: {
                                            Label("Business", systemImage: TripPurpose.business.iconName)
                                        }
                                        .tint(TripPurpose.business.mapTint)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            classify(visit, as: .personal)
                                        } label: {
                                            Label("Personal", systemImage: TripPurpose.personal.iconName)
                                        }
                                        .tint(TripPurpose.personal.mapTint)
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, $editMode)
                    .safeAreaInset(edge: .bottom) {
                        if editMode.isEditing && !selection.isEmpty {
                            bulkClassifyBar
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TRIPS")
                        .font(TE.mono(.caption, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(TE.textMuted)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Select") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            if editMode.isEditing {
                                editMode = .inactive
                                selection.removeAll()
                            } else {
                                editMode = .active
                            }
                        }
                    }
                }
            }
            .onAppear { viewModel.loadAllVisits() }
        }
    }

    private var groupedVisits: [(day: Date, title: String, visits: [Visit])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: viewModel.allVisits) { visit in
            calendar.startOfDay(for: visit.arrivedAt)
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        return grouped.keys.sorted(by: >).map { day in
            (
                day: day,
                title: formatter.string(from: day).uppercased(),
                visits: (grouped[day] ?? []).sorted { $0.arrivedAt > $1.arrivedAt }
            )
        }
    }

    private var bulkClassifyBar: some View {
        VStack(spacing: 10) {
            TextField("Business sub-purpose", text: $bulkSubPurpose)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                bulkButton("Business", icon: TripPurpose.business.iconName, purpose: .business)
                bulkButton("Personal", icon: TripPurpose.personal.iconName, purpose: .personal)
                bulkButton("Clear", icon: TripPurpose.unclassified.iconName, purpose: .unclassified)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func bulkButton(_ title: String, icon: String, purpose: TripPurpose) -> some View {
        Button {
            viewModel.bulkUpdateClassification(selectedVisits, purpose: purpose, subPurpose: bulkSubPurpose)
            selection.removeAll()
            bulkSubPurpose = ""
            editMode = .inactive
        } label: {
            Label(title, systemImage: icon)
                .font(TE.mono(.caption, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(purpose.mapTint)
        .controlSize(.small)
    }

    private func classify(_ visit: Visit, as purpose: TripPurpose) {
        viewModel.updateVisitClassification(visit, purpose: purpose, subPurpose: visit.subPurpose)
    }
}

private struct TripListRow: View {
    let visit: Visit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(visit.purpose.mapTint)
                    .frame(width: 34, height: 34)
                Image(systemName: visit.purpose.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(visit.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(visit.formattedTimeRange)
                    Text("•")
                    Text(visit.formattedDuration)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(visit.purpose.label.uppercased())
                    .font(TE.mono(.caption2, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(visit.purpose.mapTint)

                if let subPurpose = visit.subPurpose, !subPurpose.isEmpty {
                    Text(subPurpose)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OnboardingView: View {
    let viewModel: LocationViewModel
    let onComplete: (Bool) -> Void

    @ObservedObject private var locationManager: LocationManager

    @State private var selectedPage = 0
    @State private var startTrackingWhenDone = false
    @State private var selectedTrackingMode: TrackingMode = .fullHistory

    private let pageCount = 5

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

                    purposePage
                        .tag(1)

                    featuresPage
                        .tag(2)

                    permissionsPage
                        .tag(3)

                    finishPage
                        .tag(4)
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
            guard selectedPage == 3 else { return }
            if newStatus == .authorizedAlways {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    selectedPage = 4
                }
            }
        }
    }

    private var welcomePage: some View {
        LocationOnboardingPageView(
            icon: "",
            eyebrow: "Welcome",
            title: "ISO.ME",
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

    private var purposePage: some View {
        LocationOnboardingPageView(
            icon: "slider.horizontal.3",
            eyebrow: "Tracking Mode",
            title: "WHY ARE YOU USING ISO.ME?",
            description: "Pick a starting mode. You can change it later in Settings."
        ) {
            VStack(spacing: 12) {
                OnboardingModeOption(
                    title: "Full history",
                    description: "Visits, map pins, routes, and exports.",
                    icon: "map.fill",
                    isSelected: selectedTrackingMode == .fullHistory
                ) {
                    selectedTrackingMode = .fullHistory
                }

                OnboardingModeOption(
                    title: "Mileage tracking",
                    description: "Vehicle trips only, with visit logging turned off.",
                    icon: "car.fill",
                    isSelected: selectedTrackingMode == .drivesOnly
                ) {
                    selectedTrackingMode = .drivesOnly
                }
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

                    Text("BACKGROUND VISIT DETECTION")
                        .font(.onboardingTitle)
                        .tracking(1.2)
                        .foregroundStyle(OnboardingPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Background visit detection lets iso.me keep recording when the app is closed.")
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
                            : "Needs extended location access",
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

                Text("iso.me uses your location to detect places you visit and trace your daily path.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    locationManager.requestWhenInUseAuthorization()
                } label: {
                    Label("Continue", systemImage: "location.fill")
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

                Text("Background visit detection requires extended location access so iso.me keeps recording when the app is closed.")
                    .font(.onboardingCaption)
                    .foregroundStyle(OnboardingPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    locationManager.requestAlwaysAuthorization()
                } label: {
                    Label("Continue", systemImage: "arrow.up.forward.app.fill")
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

                Text("Grant location access in iPhone Settings → iso.me → Location.")
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
                    icon: "lock.fill",
                    title: "Privacy",
                    value: "Stored on-device"
                )

                OnboardingSummaryRow(
                    icon: selectedTrackingMode == .drivesOnly ? "car.fill" : "map.fill",
                    title: "Mode",
                    value: selectedTrackingMode.title
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

            if !isAwaitingPermissionRequest {
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
    }

    private var isAwaitingPermissionRequest: Bool {
        selectedPage == 3 && locationManager.authorizationStatus == .notDetermined
    }

    private var primaryButtonTitle: String {
        if selectedPage == pageCount - 1 {
            return String(localized: "Get Started")
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
        locationManager.setTrackingMode(selectedTrackingMode)
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

private struct OnboardingModeOption: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? OnboardingPalette.accent.opacity(0.18) : OnboardingPalette.cardSoft)
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? OnboardingPalette.accent : OnboardingPalette.textSecondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.onboardingBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(OnboardingPalette.textPrimary)

                    Text(description)
                        .font(.onboardingCaption)
                        .foregroundStyle(OnboardingPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? OnboardingPalette.accent : OnboardingPalette.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onboardingCard(padding: 14, fill: isSelected ? OnboardingPalette.card : OnboardingPalette.cardSoft)
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
        .modelContainer(for: [Visit.self, LocationPoint.self, Vehicle.self], inMemory: true)
}
