import SwiftUI

struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    var context: OnboardingAnalyticsPaywallContext = .export

    @Environment(\.dismiss) private var dismiss
    @State private var didTrackPaywallShown = false
    @State private var selectedOption: IsoMePurchaseOption = .individual

    private let analytics = OnboardingAnalyticsClient.shared

    private var isManagingPurchase: Bool {
        context == .settings && storeManager.isPurchased
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    if isManagingPurchase {
                        managementContent
                    } else {
                        unlockContent
                    }

                    purchaseError
                    restoreButton
                    purchaseDisclosure
                }
                .padding(.horizontal, 24)
                .padding(.top, 52)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityLabel("Dismiss")
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--review-family-paywall") {
                selectedOption = .family
            }
            #endif
            trackPaywallShownIfNeeded()
        }
        .task {
            if !usesStaticReviewPrices,
               (!storeManager.isPurchased || storeManager.canBuyFamilyUpgrade) {
                await storeManager.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 92, height: 92)

                Image(systemName: isManagingPurchase ? "person.3.fill" : "square.and.arrow.up")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text(isManagingPurchase ? "Purchases & Family" : "Unlock Data Export")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(isManagingPurchase
                     ? "Manage your lifetime export purchase and Family Sharing."
                     : "Export your visits, points, routes, and country days. Tracking stays free and unlimited.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var unlockContent: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "doc.on.doc", text: "Export in all supported formats")
                featureRow(icon: "folder", text: "Auto-save to a folder of your choice")
                featureRow(icon: "checkmark.seal.fill", text: "One-time payment, no subscription")
                featureRow(icon: "person.3.fill", text: "Choose Individual or Family Lifetime")
                featureRow(icon: "lock.shield.fill", text: "Completely private and on-device")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Plan", selection: $selectedOption) {
                Text("Individual").tag(IsoMePurchaseOption.individual)
                Text("Family").tag(IsoMePurchaseOption.family)
            }
            .pickerStyle(.segmented)

            planCard(for: selectedOption)
            purchaseButton(for: selectedOption)
        }
    }

    @ViewBuilder
    private var managementContent: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: storeManager.isFamilyUnlocked ? "person.3.fill" : "person.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text(currentPlanTitle)
                        .font(.headline)
                    Text(currentPlanDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if storeManager.canBuyFamilyUpgrade {
                VStack(spacing: 12) {
                    featureRow(icon: "person.3.fill", text: "Share export access with up to 5 family members")
                    featureRow(icon: "arrow.up.right.circle.fill", text: "Pay only the difference from Individual Lifetime")
                    purchaseButton(for: .familyUpgrade)
                }
            }
        }
    }

    private var currentPlanTitle: LocalizedStringKey {
        if storeManager.isFamilyUnlocked {
            return "Family Lifetime active"
        }
        if storeManager.isIndividualUnlocked {
            return "Individual Lifetime active"
        }
        return "Lifetime Export active"
    }

    private var currentPlanDetail: LocalizedStringKey {
        if storeManager.isFamilyUnlocked {
            return "Family Sharing is included. Existing lifetime owners have been grandfathered into this plan."
        }
        if storeManager.canBuyFamilyUpgrade {
            return "Your export access is permanent. Upgrade once to share it through Apple Family Sharing."
        }
        return "Your export access is permanent."
    }

    private func planCard(for option: IsoMePurchaseOption) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: option == .individual ? "person.fill" : "person.3.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(planTitle(for: option))
                    .font(.headline)
                Text(planSubtitle(for: option))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let price = displayPrice(for: option) {
                Text(price)
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .fixedSize(horizontal: true, vertical: false)
            } else if storeManager.isLoadingProducts {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(18)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func purchaseButton(for option: IsoMePurchaseOption) -> some View {
        Button {
            purchase(option)
        } label: {
            HStack(spacing: 10) {
                if storeManager.purchasingOption == option {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(purchaseButtonTitle(for: option))
                        .font(.headline)

                    if let price = displayPrice(for: option) {
                        Spacer(minLength: 8)
                        Text(price)
                            .font(.headline)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(
            !isPurchaseOptionAvailable(option)
                || storeManager.isLoading
                || (option == .familyUpgrade && !storeManager.canBuyFamilyUpgrade)
        )
    }

    private var usesStaticReviewPrices: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--review-paywall")
            || arguments.contains("--review-upgrade-paywall")
        #else
        return false
        #endif
    }

    private func displayPrice(for option: IsoMePurchaseOption) -> String? {
        if let product = storeManager.product(for: option) {
            return product.displayPrice
        }

        guard usesStaticReviewPrices else { return nil }
        return option == .family ? "$20.00" : "$10.00"
    }

    private func isPurchaseOptionAvailable(_ option: IsoMePurchaseOption) -> Bool {
        storeManager.product(for: option) != nil || usesStaticReviewPrices
    }

    private var restoreButton: some View {
        Button {
            restore()
        } label: {
            HStack(spacing: 8) {
                if storeManager.isRestoring {
                    ProgressView()
                        .controlSize(.small)
                }
                Text("Restore Purchase")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
        .disabled(storeManager.isLoading)
    }

    @ViewBuilder
    private var purchaseError: some View {
        if let error = storeManager.purchaseError ?? storeManager.productLoadError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var purchaseDisclosure: some View {
        Text("Lifetime plans are one-time purchases charged to your Apple ID. Family plans require Apple Family Sharing and Purchase Sharing.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func planTitle(for option: IsoMePurchaseOption) -> LocalizedStringKey {
        switch option {
        case .individual:
            return "Individual Lifetime"
        case .family:
            return "Family Lifetime"
        case .familyUpgrade:
            return "Upgrade to Family Lifetime"
        }
    }

    private func planSubtitle(for option: IsoMePurchaseOption) -> LocalizedStringKey {
        switch option {
        case .individual:
            return "Permanent export access for your Apple ID"
        case .family:
            return "Permanent export access shared with up to 5 family members"
        case .familyUpgrade:
            return "Add Family Sharing to your Individual Lifetime purchase"
        }
    }

    private func purchaseButtonTitle(for option: IsoMePurchaseOption) -> LocalizedStringKey {
        switch option {
        case .individual:
            return "Buy Individual Lifetime"
        case .family:
            return "Buy Family Lifetime"
        case .familyUpgrade:
            return "Upgrade to Family"
        }
    }

    private func purchase(_ option: IsoMePurchaseOption) {
        let dismissAfterSuccess = !isManagingPurchase
        analytics.trackPurchaseStarted(
            context: context,
            productId: option.analyticsProductID
        )

        Task {
            let outcome = await storeManager.purchase(option)
            let analyticsResult = analyticsResult(for: outcome)
            analytics.trackPurchaseFinished(
                outcome: analyticsResult.outcome,
                context: context,
                errorCategory: analyticsResult.errorCategory,
                productId: option.analyticsProductID
            )

            if outcome == .succeeded, dismissAfterSuccess {
                dismiss()
            }
        }
    }

    private func restore() {
        let dismissAfterSuccess = !isManagingPurchase
        analytics.trackRestoreStarted(context: context)

        Task {
            let outcome = await storeManager.restorePurchases()
            let analyticsResult = analyticsResult(for: outcome)
            analytics.trackRestoreFinished(
                outcome: analyticsResult.outcome,
                context: context,
                errorCategory: analyticsResult.errorCategory
            )

            if outcome == .restored, dismissAfterSuccess {
                dismiss()
            }
        }
    }

    private func analyticsResult(
        for outcome: StorePurchaseOutcome
    ) -> (outcome: OnboardingAnalyticsPurchaseOutcome, errorCategory: OnboardingAnalyticsErrorCategory?) {
        switch outcome {
        case .succeeded:
            return (.succeeded, nil)
        case .cancelled:
            return (.cancelled, .userCancelled)
        case .pending:
            return (.pending, .paymentPending)
        case .failed(let failure):
            switch failure {
            case .notEligible:
                return (.failed, .notUnlocked)
            case .productUnavailable:
                return (.failed, .productUnavailable)
            case .verificationFailed:
                return (.failed, .verificationFailed)
            case .storeError:
                return (.failed, storeErrorCategory)
            }
        }
    }

    private func analyticsResult(
        for outcome: StoreRestoreOutcome
    ) -> (outcome: OnboardingAnalyticsPurchaseOutcome, errorCategory: OnboardingAnalyticsErrorCategory?) {
        switch outcome {
        case .restored:
            return (.restored, nil)
        case .notFound:
            return (.notFound, .notUnlocked)
        case .failed:
            return (.failed, storeErrorCategory)
        }
    }

    private var storeErrorCategory: OnboardingAnalyticsErrorCategory {
        guard let error = storeManager.purchaseError?.lowercased() else { return .unknown }
        if error.contains("network") || error.contains("internet") || error.contains("offline") {
            return .networkUnavailable
        }
        return .storeUnavailable
    }

    private func trackPaywallShownIfNeeded() {
        guard !didTrackPaywallShown else { return }
        didTrackPaywallShown = true
        analytics.trackPaywallShown(context: context)
    }

    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
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
