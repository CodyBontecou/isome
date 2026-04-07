import Foundation
import StoreKit

/// Manages the one-time lifetime unlock purchase via StoreKit 2.
/// Transaction history is stored server-side by Apple and survives uninstall/reinstall.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    nonisolated static let lifetimeProductID = "com.bontecou.OwnPath.lifetime"

    @Published private(set) var product: Product?
    @Published private(set) var isPurchased: Bool = false
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading: Bool = false

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await checkEntitlement()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Product Loading

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.lifetimeProductID])
            product = products.first
        } catch {
            purchaseError = "Failed to load product: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
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

        // Sync with App Store to get latest transaction state
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

    /// Check current entitlements — this works after reinstall because Apple maintains
    /// transaction history server-side.
    func checkEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                isPurchased = true
                return
            }
        }
        // If we get here, no valid entitlement was found
        // Only set to false if we actually iterated (not on first launch race)
        isPurchased = false
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        let productID = Self.lifetimeProductID
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.productID == productID {
                        await MainActor.run {
                            self?.isPurchased = transaction.revocationDate == nil
                        }
                    }
                }
            }
        }
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
