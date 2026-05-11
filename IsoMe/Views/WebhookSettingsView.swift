import SwiftUI

/// Configuration UI for the HTTP webhook delivery feature.
/// Embedded in SettingsView via a NavigationLink.
struct WebhookSettingsView: View {
    @ObservedObject private var storeManager = StoreManager.shared
    @ObservedObject private var webhook = WebhookManager.shared
    @State private var showingPaywall = false
    @State private var testResult: String?
    @State private var testError: String?
    @State private var isTesting = false
    @AppStorage("webhook.privacyWarningDismissed") private var privacyWarningDismissed = false

    var body: some View {
        ZStack {
            TE.surface.ignoresSafeArea()

            if storeManager.isPurchased {
                ScrollView {
                    VStack(spacing: 0) {
                        if !privacyWarningDismissed {
                            privacyWarning
                        }
                        enableSection
                        if webhook.isEnabled {
                            endpointSection
                            authSection
                            sendModeSection
                            statusSection
                            actionsSection
                        }
                        Spacer().frame(height: 32)
                    }
                }
            } else {
                lockedState
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("WEBHOOK")
                    .font(TE.mono(.caption, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(TE.textMuted)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(storeManager: storeManager)
        }
    }

    // MARK: - Locked

    private var lockedState: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.title.weight(.light))
                .foregroundStyle(TE.textMuted)
            Text("WEBHOOK LOCKED")
                .font(TE.mono(.caption, weight: .bold))
                .tracking(2)
                .foregroundStyle(TE.textPrimary)
            Text("Export features require a one-time purchase.")
                .font(TE.mono(.caption2, weight: .medium))
                .foregroundStyle(TE.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 32)
            Button {
                showingPaywall = true
            } label: {
                Text("UNLOCK EXPORT")
                    .font(TE.mono(.caption, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 44)
                    .background(TE.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Privacy

    private var privacyWarning: some View {
        VStack(spacing: 0) {
            TECard {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(TE.warning)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DATA LEAVES YOUR DEVICE")
                            .font(TE.mono(.caption2, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(TE.warning)
                        Text("Enabling webhook delivery sends your location data to an external server you configure. iso.me does not have access to this server or the transmitted data.")
                            .font(TE.mono(.caption2, weight: .regular))
                            .foregroundStyle(TE.textMuted)
                            .lineSpacing(2)
                    }
                    Spacer(minLength: 0)
                    Button {
                        privacyWarningDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TE.textMuted)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss warning")
                }
                .padding(12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }

    // MARK: - Enable

    private var enableSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ENABLE")

            TECard {
                TERow(showDivider: false) {
                    Toggle(isOn: $webhook.isEnabled) {
                        Text("WEBHOOK DELIVERY")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)
                    }
                    .toggleStyle(TEToggleStyle())
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: webhook.isEnabled
                ? "Location data will be POSTed to the configured endpoint."
                : "Send location data to an external API or self-hosted server.")
        }
    }

    // MARK: - Endpoint

    private var endpointSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ENDPOINT")

            TECard {
                TERow {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("URL")
                            .font(TE.mono(.caption2, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(TE.textMuted)
                        TextField("https://example.com/api/location", text: $webhook.urlString)
                            .font(TE.mono(.caption, weight: .medium))
                            .foregroundStyle(TE.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                    }
                }

                TERow(showDivider: false) {
                    HStack {
                        Text("FORMAT")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)
                        Spacer()
                        Picker("", selection: $webhook.format) {
                            Text("OWNTRACKS").tag(ExportFormat.owntracks)
                            Text("OVERLAND").tag(ExportFormat.overland)
                            Text("JSON").tag(ExportFormat.json)
                            Text("CSV").tag(ExportFormat.csv)
                            Text("GPX").tag(ExportFormat.gpx)
                            Text("GEOJSON").tag(ExportFormat.geojson)
                            Text("MARKDOWN").tag(ExportFormat.markdown)
                        }
                        .labelsHidden()
                        .tint(TE.accent)
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "OwnTracks format works with Dawarich (api/v1/owntracks/points), OwnTracks Recorder (/pub), and Traccar.")
        }
    }

    // MARK: - Auth

    private var authSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "AUTH")

            TECard {
                TERow {
                    HStack {
                        Text("TYPE")
                            .font(TE.mono(.caption2, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(TE.textMuted)
                        Spacer()
                        Picker("", selection: $webhook.authType) {
                            ForEach(WebhookManager.AuthType.allCases) { type in
                                Text(LocalizedStringKey(type.label)).tag(type)
                            }
                        }
                        .labelsHidden()
                        .tint(TE.accent)
                    }
                }

                switch webhook.authType {
                case .none:
                    EmptyView()

                case .apiKeyQuery:
                    TERow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PARAM NAME")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            TextField("api_key", text: $webhook.authKey)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    TERow(showDivider: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API KEY")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            SecureField("••••••••", text: $webhook.authValue)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                        }
                    }

                case .bearer:
                    TERow(showDivider: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TOKEN")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            SecureField("••••••••", text: $webhook.authValue)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                        }
                    }

                case .basic:
                    TERow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("USERNAME")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            TextField("user", text: $webhook.authUsername)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    TERow(showDivider: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PASSWORD")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            SecureField("••••••••", text: $webhook.authValue)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                        }
                    }

                case .customHeader:
                    TERow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HEADER NAME")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            TextField("X-API-Key", text: $webhook.authKey)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                        }
                    }
                    TERow(showDivider: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("HEADER VALUE")
                                .font(TE.mono(.caption2, weight: .semibold))
                                .tracking(1)
                                .foregroundStyle(TE.textMuted)
                            SecureField("••••••••", text: $webhook.authValue)
                                .font(TE.mono(.caption, weight: .medium))
                                .foregroundStyle(TE.textPrimary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: webhook.authType == .apiKeyQuery
                ? "The key and value are appended as a query string (?key=value)."
                : "Credentials are sent as HTTP headers and stored in the device keychain.")
        }
    }

    // MARK: - Send mode

    private var sendModeSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "SEND MODE")

            TECard {
                TERow(showDivider: webhook.sendMode == .batchCount || webhook.sendMode == .batchTime) {
                    HStack {
                        Text("MODE")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)
                        Spacer()
                        Picker("", selection: $webhook.sendMode) {
                            ForEach(WebhookManager.SendMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.label)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .tint(TE.accent)
                    }
                }

                if webhook.sendMode == .batchCount {
                    TERow(showDivider: false) {
                        HStack {
                            Text("COUNT")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Picker("", selection: $webhook.batchCount) {
                                Text("5").tag(5)
                                Text("10").tag(10)
                                Text("25").tag(25)
                                Text("50").tag(50)
                                Text("100").tag(100)
                            }
                            .labelsHidden()
                            .tint(TE.accent)
                        }
                    }
                } else if webhook.sendMode == .batchTime {
                    TERow(showDivider: false) {
                        HStack {
                            Text("INTERVAL")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Picker("", selection: $webhook.batchTimeMinutes) {
                                Text("1 min").tag(1)
                                Text("5 min").tag(5)
                                Text("15 min").tag(15)
                                Text("30 min").tag(30)
                                Text("1 hour").tag(60)
                            }
                            .labelsHidden()
                            .tint(TE.accent)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: sendModeFooter)
        }
    }

    private var sendModeFooter: LocalizedStringKey {
        switch webhook.sendMode {
        case .realtime:
            return "Each new GPS fix is POSTed immediately."
        case .batchCount:
            return "Points are queued in memory and sent when the count is reached. Unsent points are lost if the app is terminated."
        case .batchTime:
            return "Points are queued and flushed every N minutes. Unsent points are lost if the app is terminated."
        case .manual:
            return "Data is only sent when you tap \"Send Now\" below."
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "STATUS")

            TECard {
                TERow(showDivider: hasQueuedPoints || webhook.lastError != nil) {
                    HStack {
                        Text("LAST SENT")
                            .font(TE.mono(.caption, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)
                        Spacer()
                        Text(lastSentText)
                            .font(TE.mono(.caption2, weight: .medium))
                            .foregroundStyle(TE.textMuted)
                    }
                }

                if hasQueuedPoints {
                    TERow {
                        HStack {
                            Text("QUEUED")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.textPrimary)
                            Spacer()
                            Text("\(webhook.queuedPointCount) POINTS")
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.accent)
                        }
                    }

                    TERow(showDivider: webhook.lastError != nil) {
                        Button {
                            Task { await webhook.flushBatch() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(TE.accent)
                                Text("FLUSH QUEUE")
                                    .font(TE.mono(.caption, weight: .medium))
                                    .tracking(1)
                                    .foregroundStyle(TE.accent)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = webhook.lastError {
                    TERow(showDivider: false) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(TE.danger)
                            Text(error)
                                .font(TE.mono(.caption2, weight: .regular))
                                .foregroundStyle(TE.danger)
                                .lineSpacing(2)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var hasQueuedPoints: Bool {
        webhook.sendMode != .manual && webhook.queuedPointCount > 0
    }

    private var lastSentText: String {
        guard let last = webhook.lastSentAt else { return "NEVER" }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: last)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 0) {
            TESectionHeader(title: "ACTIONS")

            TECard {
                TERow {
                    Button {
                        isTesting = true
                        testResult = nil
                        testError = nil
                        Task {
                            do {
                                testResult = try await webhook.testConnection()
                            } catch {
                                testError = error.localizedDescription
                            }
                            isTesting = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TE.accent)
                            Text(isTesting ? "TESTING…" : "TEST CONNECTION")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.accent)
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(TE.accent)
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(TE.accent.opacity(0.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
                }

                if let result = testResult {
                    TERow(showDivider: true) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(TE.success)
                            Text(result)
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.success)
                        }
                    }
                }

                if let error = testError {
                    TERow(showDivider: true) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(TE.danger)
                            Text(error)
                                .font(TE.mono(.caption2, weight: .medium))
                                .foregroundStyle(TE.danger)
                        }
                    }
                }

                TERow(showDivider: false) {
                    Button {
                        Task { await webhook.sendNow() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TE.accent)
                            Text("SEND NOW")
                                .font(TE.mono(.caption, weight: .medium))
                                .tracking(1)
                                .foregroundStyle(TE.accent)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(TE.accent.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            TESectionFooter(text: "Use Test Connection to verify the endpoint URL and credentials without sending real data. Send Now posts all saved location data to the endpoint.")
        }
    }
}

#Preview {
    NavigationStack {
        WebhookSettingsView()
    }
}
