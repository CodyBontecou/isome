import SwiftUI

struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    var context: OnboardingAnalyticsPaywallContext = .export

    @Environment(\.dismiss) private var dismiss
    @State private var didTrackPaywallShown = false
    private let analytics = OnboardingAnalyticsClient.shared

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "square.and.arrow.up")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
            }

            // Title
            VStack(spacing: 8) {
                Text("Unlock Data Export")
                    .font(.title.bold())

                Text("Export your visits, points, and routes in JSON, CSV, or Markdown. Tracking stays free and unlimited.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Features
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "doc.on.doc", text: "Export to JSON, CSV, or Markdown")
                featureRow(icon: "folder", text: "Auto-save to a folder of your choice")
                featureRow(icon: "checkmark.seal.fill", text: "One-time payment, no subscription")
                featureRow(icon: "lock.shield.fill", text: "Still 100% private & on-device")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Purchase button
            VStack(spacing: 12) {
                Button {
                    Task {
                        analytics.trackPurchaseStarted(context: context)
                        await storeManager.purchase()
                        let result = purchaseAnalyticsResult()
                        analytics.trackPurchaseFinished(
                            outcome: result.outcome,
                            context: context,
                            errorCategory: result.errorCategory
                        )
                    }
                } label: {
                    Group {
                        if storeManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else if let product = storeManager.product {
                            Text("Unlock Export — \(product.displayPrice)")
                                .font(.headline)
                        } else {
                            Text("Loading...")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                }
                .disabled(storeManager.product == nil || storeManager.isLoading)

                Button {
                    Task {
                        analytics.trackRestoreStarted(context: context)
                        await storeManager.restorePurchases()
                        let result = restoreAnalyticsResult()
                        analytics.trackRestoreFinished(
                            outcome: result.outcome,
                            context: context,
                            errorCategory: result.errorCategory
                        )
                    }
                } label: {
                    Text("Restore Purchase")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .disabled(storeManager.isLoading)

                if let error = storeManager.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            trackPaywallShownIfNeeded()
        }
    }

    private func trackPaywallShownIfNeeded() {
        guard !didTrackPaywallShown else { return }
        didTrackPaywallShown = true
        analytics.trackPaywallShown(context: context)
    }

    private func purchaseAnalyticsResult() -> (outcome: OnboardingAnalyticsPurchaseOutcome, errorCategory: OnboardingAnalyticsErrorCategory?) {
        if storeManager.isPurchased {
            return (.succeeded, nil)
        }

        guard let error = storeManager.purchaseError?.lowercased() else {
            return (.cancelled, .userCancelled)
        }

        if error.contains("pending") {
            return (.pending, .paymentPending)
        }
        if error.contains("not available") || error.contains("loading") {
            return (.failed, .productUnavailable)
        }
        if error.contains("network") || error.contains("internet") || error.contains("offline") {
            return (.failed, .networkUnavailable)
        }

        return (.failed, .unknown)
    }

    private func restoreAnalyticsResult() -> (outcome: OnboardingAnalyticsPurchaseOutcome, errorCategory: OnboardingAnalyticsErrorCategory?) {
        if storeManager.isPurchased {
            return (.restored, nil)
        }

        guard let error = storeManager.purchaseError?.lowercased() else {
            return (.failed, .unknown)
        }

        if error.contains("no previous") {
            return (.notFound, .notUnlocked)
        }
        if error.contains("network") || error.contains("internet") || error.contains("offline") {
            return (.failed, .networkUnavailable)
        }

        return (.failed, .unknown)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 24)

            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PaywallView(storeManager: StoreManager.shared)
}
