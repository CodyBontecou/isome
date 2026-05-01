import SwiftUI

let discordInviteURL = URL(string: "https://discord.gg/RaQYS4t6gn")!

struct DiscordPromoBanner: View {
    @Environment(\.openURL) private var openURL
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                openURL(discordInviteURL)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TE.accent)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("JOIN THE COMMUNITY")
                            .font(TE.mono(.caption, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(TE.textPrimary)

                        Text("Chat with us on Discord")
                            .font(TE.mono(.caption2))
                            .foregroundStyle(TE.textMuted)
                    }

                    Spacer(minLength: 8)

                    Text("JOIN")
                        .font(TE.mono(.caption2, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(TE.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(TE.accent.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(TE.accent.opacity(0.32), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Join the Discord community.")
            .accessibilityAddTraits(.isButton)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TE.textMuted)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss Discord banner.")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(TE.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(TE.border, lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        TE.surface.ignoresSafeArea()
        DiscordPromoBanner(onDismiss: {})
            .padding()
    }
}
