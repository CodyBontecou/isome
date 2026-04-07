import SwiftUI

/// Teenage Engineering–inspired design tokens shared across all views.
enum TE {
    // MARK: - Colors
    static let accent = Color(red: 0.196, green: 0.455, blue: 0.956)
    static let surface = Color(red: 0.96, green: 0.955, blue: 0.94)
    static let surfaceDark = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let card = Color.white
    static let border = Color(red: 0.82, green: 0.81, blue: 0.79)
    static let borderDark = Color(red: 0.25, green: 0.25, blue: 0.25)
    static let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let textMuted = Color(red: 0.52, green: 0.51, blue: 0.49)
    static let lcdGreen = Color(red: 0.0, green: 0.78, blue: 0.45)
    static let lcdBackground = Color(red: 0.88, green: 0.90, blue: 0.85)
    static let danger = Color(red: 0.85, green: 0.2, blue: 0.15)
    static let warning = Color(red: 0.92, green: 0.61, blue: 0.14)
    static let success = Color(red: 0.17, green: 0.67, blue: 0.42)

    // MARK: - Typography
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style, design: .monospaced).weight(weight)
    }
}

// MARK: - Reusable Components

/// TE-styled section header: uppercase, tracked, monospaced.
struct TESectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(TE.mono(.caption2, weight: .semibold))
            .tracking(2)
            .foregroundStyle(TE.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }
}

/// TE-styled card container with 4px radius and 1px border.
struct TECard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
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

/// A single row inside a TECard, with optional bottom divider.
struct TERow<Content: View>: View {
    let showDivider: Bool
    let content: Content

    init(showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.showDivider = showDivider
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

            if showDivider {
                Divider()
                    .background(TE.border)
                    .padding(.leading, 16)
            }
        }
    }
}

/// TE-styled section footer text.
struct TESectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TE.mono(.caption2, weight: .regular))
            .foregroundStyle(TE.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }
}
