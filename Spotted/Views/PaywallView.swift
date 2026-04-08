import SwiftUI

struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }

            // Title
            VStack(spacing: 8) {
                Text("Free Limit Reached")
                    .font(.title.bold())

                Text("You've used your 10 hours of free tracking. Unlock unlimited tracking with a one-time purchase.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Features
            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "infinity", text: "Unlimited tracking forever")
                featureRow(icon: "purchased", text: "One-time payment, no subscription")
                featureRow(icon: "lock.shield.fill", text: "Still 100% private & on-device")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Purchase button
            VStack(spacing: 12) {
                Button {
                    Task {
                        await storeManager.purchase()
                    }
                } label: {
                    Group {
                        if storeManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else if let product = storeManager.product {
                            Text("Unlock Spotted — \(product.displayPrice)")
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
                        await storeManager.restorePurchases()
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
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
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
