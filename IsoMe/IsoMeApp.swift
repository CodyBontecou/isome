import SwiftUI
import SwiftData
import StoreKit

@main
struct IsoMeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var sessionStart: Date?
    @State private var startup = ModelContainerRecovery.makeStartup()
    @State private var allowTemporaryStore = false
    @AppStorage("hasRequestedReview") private var hasRequestedReview = false
    @AppStorage("cumulativeUsageSeconds") private var cumulativeUsageSeconds: Double = 0

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootStartupView(
                startup: startup,
                allowTemporaryStore: allowTemporaryStore,
                retry: retryPersistentStore,
                resetAndRetry: resetStoreAndRetry,
                continueTemporarily: { allowTemporaryStore = true }
            )
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                    guard startup.isPersistent else { return }
                    DailyExportScheduler.shared.attach(modelContainer: startup.container)
                    await DailyExportScheduler.shared.runIfDue()
                }
        }
        .modelContainer(startup.container)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                sessionStart = Date()
                requestReviewIfEligible()
                NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
                if startup.isPersistent {
                    Task { await DailyExportScheduler.shared.runIfDue() }
                }
            case .inactive:
                break
            case .background:
                if let start = sessionStart {
                    cumulativeUsageSeconds += Date().timeIntervalSince(start)
                    sessionStart = nil
                }
                NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
                DailyExportScheduler.shared.scheduleNextBackgroundRun()
            @unknown default:
                break
            }
        }
    }
    
    private func requestReviewIfEligible() {
        guard !hasRequestedReview, cumulativeUsageSeconds >= 1800 else { return }
        hasRequestedReview = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "isome" else { return }

        switch url.host {
        case "stop":
            NotificationCenter.default.post(name: .stopTracking, object: nil)
        default:
            break
        }
    }

    private func retryPersistentStore() {
        startup = ModelContainerRecovery.makeStartup()
        allowTemporaryStore = startup.isPersistent
    }

    private func resetStoreAndRetry() {
        do {
            try ModelContainerRecovery.resetDefaultStoreFiles()
            LogManager.shared.warning("Reset default SwiftData store files after startup recovery request")
        } catch {
            let failure = ModelContainerRecovery.sanitizedFailure(
                operation: "Default SwiftData store reset",
                error: error
            )
            LogManager.shared.error(failure.diagnosticSummary)
        }

        retryPersistentStore()
    }
}

private struct RootStartupView: View {
    let startup: ModelContainerRecovery.Startup
    let allowTemporaryStore: Bool
    let retry: () -> Void
    let resetAndRetry: () -> Void
    let continueTemporarily: () -> Void

    var body: some View {
        switch startup.mode {
        case .persistent:
            ContentView()
        case .inMemoryFallback(let failure):
            if allowTemporaryStore {
                ContentView(isTemporaryStore: true)
            } else {
                DataStoreRecoveryView(
                    failure: failure,
                    retry: retry,
                    resetAndRetry: resetAndRetry,
                    continueTemporarily: continueTemporarily
                )
            }
        }
    }
}

private struct DataStoreRecoveryView: View {
    let failure: ModelContainerRecovery.ContainerFailure
    let retry: () -> Void
    let resetAndRetry: () -> Void
    let continueTemporarily: () -> Void

    private var diagnostics: String {
        ModelContainerRecovery.diagnosticsText(
            for: failure,
            modeDescription: "Persistent store unavailable; in-memory fallback ready"
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TE.surface.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LOCAL DATA UNAVAILABLE")
                                .font(TE.mono(.title2, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(TE.textPrimary)

                            Text("IsoMe could not load its local location history store. Your precise location history is not shown here, and tracking is paused until the store opens or you choose a temporary session.")
                                .font(.body)
                                .foregroundStyle(TE.textMuted)
                        }

                        TECard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Temporary mode is not saved", systemImage: "exclamationmark.triangle")
                                    .font(TE.mono(.caption, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(TE.warning)

                                Text("Continuing uses an in-memory store. Anything recorded in that mode can disappear when IsoMe closes.")
                                    .font(.subheadline)
                                    .foregroundStyle(TE.textMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 12) {
                            Button(action: retry) {
                                Label("Retry Loading Data", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive, action: resetAndRetry) {
                                Label("Reset Local Store and Retry", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(action: continueTemporarily) {
                                Label("Continue Temporarily", systemImage: "clock")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            ShareLink(item: diagnostics) {
                                Label("Export Diagnostics", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        Text(failure.diagnosticSummary)
                            .font(TE.mono(.caption2))
                            .foregroundStyle(TE.textMuted)
                            .textSelection(.enabled)
                    }
                    .padding(24)
                    .frame(maxWidth: 560, alignment: .leading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    static let stopTracking = Notification.Name("stopTracking")
}
