import Foundation
import StoreKit

/// Manages iso.me unlock purchases via StoreKit 2.
/// Transaction history is stored server-side by Apple and survives uninstall/reinstall.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    nonisolated static let monthlyProductID = "com.bontecou.isome.monthly"
    nonisolated static let yearlyProductID = "com.bontecou.isome.yearly"
    nonisolated static let lifetimeProductID = "com.bontecou.isome.lifetime"

    /// All product identifiers currently sold by the app.
    nonisolated static var allProductIDs: [String] {
        [monthlyProductID, yearlyProductID, lifetimeProductID]
    }

    enum Plan: String, CaseIterable, Identifiable {
        case monthly
        case yearly
        case lifetime

        var id: String { rawValue }

        var productID: String {
            switch self {
            case .monthly: return StoreManager.monthlyProductID
            case .yearly: return StoreManager.yearlyProductID
            case .lifetime: return StoreManager.lifetimeProductID
            }
        }
    }

    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isPurchased: Bool = false
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading: Bool = false

    /// Backwards-compatible alias used by the existing sheet-style PaywallView.
    /// Returns the lifetime product because that view is built around a single one-time unlock.
    var product: Product? { lifetimeProduct }

    private var transactionListener: Task<Void, Never>?

    private init() {
        #if DEBUG
        let args = Set(ProcessInfo.processInfo.arguments)

        // Debug default: show free-tier behavior in-app.
        // Pass either launch argument to override:
        //  --debug-force-pro            -> always purchased
        //  --debug-use-real-storekit    -> use real StoreKit entitlement checks
        if args.contains("--debug-force-pro") {
            isPurchased = true
            Task { await loadProducts() }
            return
        }

        if !args.contains("--debug-use-real-storekit") {
            isPurchased = false
            Task { await loadProducts() }
            return
        }
        #endif

        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await checkEntitlement()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.allProductIDs)
            for product in products {
                switch product.id {
                case Self.monthlyProductID: monthlyProduct = product
                case Self.yearlyProductID: yearlyProduct = product
                case Self.lifetimeProductID: lifetimeProduct = product
                default: break
                }
            }
        } catch {
            purchaseError = "Failed to load product: \(error.localizedDescription)"
        }
    }

    func product(for plan: Plan) -> Product? {
        switch plan {
        case .monthly: return monthlyProduct
        case .yearly: return yearlyProduct
        case .lifetime: return lifetimeProduct
        }
    }

    // MARK: - Purchase

    /// Purchase the lifetime unlock — kept for backwards-compat with the sheet PaywallView.
    func purchase() async {
        await purchase(plan: .lifetime)
    }

    /// Purchase a specific plan.
    func purchase(plan: Plan) async {
        guard let product = product(for: plan) else {
            purchaseError = "Product not available"
            return
        }

        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = true
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval"
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Restore purchases — checks Apple's server-side transaction history.
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
            isLoading = false
            return
        }

        await checkEntitlement()
        if !isPurchased {
            purchaseError = "No previous purchase found"
        }
        isLoading = false
    }

    // MARK: - Entitlement Check

    /// Check current entitlements — works after reinstall because Apple maintains
    /// transaction history server-side.
    func checkEntitlement() async {
        let validIDs = Set(Self.allProductIDs)
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               validIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                isPurchased = true
                return
            }
        }
        isPurchased = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        let validIDs = Set(Self.allProductIDs)
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if validIDs.contains(transaction.productID) {
                        await self?.applyTransaction(transaction)
                    }
                }
            }
        }
    }

    private func applyTransaction(_ transaction: Transaction) {
        isPurchased = transaction.revocationDate == nil
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let item):
            return item
        }
    }
}
