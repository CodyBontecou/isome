import SwiftUI

struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            DS.Color.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    Spacer(minLength: DS.Spacing.lg)

                    iconHeader
                    titleBlock
                    featureCard

                    Spacer(minLength: DS.Spacing.lg)

                    purchaseBlock
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    // MARK: - Sections

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(DS.Color.tilePurple)
                .frame(width: 120, height: 120)
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(DS.Color.iconPurple)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Unlock data export")
                .font(DS.Font.display(.bold))
                .foregroundStyle(DS.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("You've collected your data — now take it with you. Unlock export with a one-time purchase.")
                .font(DS.Font.body())
                .foregroundStyle(DS.Color.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)
        }
    }

    private var featureCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                featureRow(symbol: "square.and.arrow.up", palette: .purple, text: "Export to JSON, CSV, or Markdown")
                featureRow(symbol: "infinity", palette: .green, text: "Unlimited tracking, always free")
                featureRow(symbol: "checkmark.seal.fill", palette: .blue, text: "One-time payment, no subscription")
                featureRow(symbol: "lock.shield.fill", palette: .peach, text: "Still 100% private & on-device")
            }
        }
    }

    private var purchaseBlock: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                Task { await storeManager.purchase() }
            } label: {
                purchaseLabel
            }
            .buttonStyle(.plain)
            .disabled(storeManager.product == nil || storeManager.isLoading)

            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("Restore purchase")
                    .font(DS.Font.body(.medium))
                    .foregroundStyle(DS.Color.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
            }
            .buttonStyle(.plain)
            .disabled(storeManager.isLoading)

            if let error = storeManager.purchaseError {
                Text(error)
                    .font(DS.Font.caption())
                    .foregroundStyle(DS.Color.danger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var purchaseLabel: some View {
        Group {
            if storeManager.isLoading {
                ProgressView().tint(.white)
            } else if let product = storeManager.product {
                Text("Unlock export — \(product.displayPrice)")
                    .font(DS.Font.headline())
            } else {
                Text("Loading…")
                    .font(DS.Font.headline())
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                .fill(DS.Color.accent)
        )
        .shadow(color: DS.Color.accent.opacity(0.28), radius: 12, x: 0, y: 6)
    }

    private func featureRow(symbol: String, palette: DS.Palette, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            CategoryIcon(symbol: symbol, palette: palette, size: 36)
            Text(text)
                .font(DS.Font.body(.medium))
                .foregroundStyle(DS.Color.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    PaywallView(storeManager: StoreManager.shared)
}
