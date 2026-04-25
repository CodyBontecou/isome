import SwiftUI

// MARK: - Tokens

/// New design system replacing TEDesign. Promotes the existing OnboardPalette
/// values to canonical app-wide tokens. Coexists with TE during migration.
enum DS {
    enum Color {
        // Base
        static let background = SwiftUI.Color(red: 253/255, green: 248/255, blue: 245/255)
        static let card = SwiftUI.Color.white
        static let divider = SwiftUI.Color(red: 0.918, green: 0.918, blue: 0.945)

        // Text
        static let textPrimary = SwiftUI.Color(red: 0.118, green: 0.149, blue: 0.282)
        static let textSecondary = SwiftUI.Color(red: 0.353, green: 0.392, blue: 0.502)
        static let textMuted = SwiftUI.Color(red: 0.541, green: 0.580, blue: 0.671)

        // Brand
        static let accent = SwiftUI.Color(red: 0.482, green: 0.467, blue: 0.929)
        static let accentGreen = SwiftUI.Color(red: 0.298, green: 0.667, blue: 0.467)
        static let danger = SwiftUI.Color(red: 0.929, green: 0.302, blue: 0.310)
        static let warning = SwiftUI.Color(red: 0.95, green: 0.65, blue: 0.30)

        // Tile / category pairs
        static let tilePurple = SwiftUI.Color(red: 0.910, green: 0.890, blue: 0.984)
        static let iconPurple = SwiftUI.Color(red: 0.482, green: 0.420, blue: 0.882)

        static let tileGreen = SwiftUI.Color(red: 0.847, green: 0.929, blue: 0.875)
        static let iconGreen = SwiftUI.Color(red: 0.298, green: 0.667, blue: 0.467)

        static let tilePeach = SwiftUI.Color(red: 0.992, green: 0.875, blue: 0.835)
        static let iconPeach = SwiftUI.Color(red: 0.929, green: 0.510, blue: 0.388)

        static let tileBlue = SwiftUI.Color(red: 0.853, green: 0.910, blue: 0.992)
        static let iconBlue = SwiftUI.Color(red: 0.239, green: 0.451, blue: 0.961)

        static let tileBrown = SwiftUI.Color(red: 0.953, green: 0.882, blue: 0.792)
        static let iconBrown = SwiftUI.Color(red: 0.659, green: 0.510, blue: 0.396)

        // Decoration carried over from OnboardPalette
        static let blobPeach = SwiftUI.Color(red: 0.984, green: 0.831, blue: 0.776).opacity(0.45)
        static let blobLavender = SwiftUI.Color(red: 0.835, green: 0.808, blue: 0.957).opacity(0.55)
        static let blobPink = SwiftUI.Color(red: 0.973, green: 0.812, blue: 0.847).opacity(0.50)
        static let sparkle = SwiftUI.Color(red: 0.808, green: 0.741, blue: 0.918)
        static let dotInactive = SwiftUI.Color(red: 0.808, green: 0.808, blue: 0.831)
    }

    enum Radius {
        static let card: CGFloat = 22
        static let tile: CGFloat = 14
        static let pill: CGFloat = 999
        static let chip: CGFloat = 10
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    enum Shadow {
        static let cardColor = SwiftUI.Color.black.opacity(0.05)
        static let cardRadius: CGFloat = 18
        static let cardY: CGFloat = 10
    }

    enum Font {
        static func display(_ weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            .system(.largeTitle, design: .rounded).weight(weight)
        }
        static func title(_ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(.title2, design: .rounded).weight(weight)
        }
        static func headline(_ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(.headline, design: .rounded).weight(weight)
        }
        static func body(_ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(.body).weight(weight)
        }
        static func caption(_ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(.caption).weight(weight)
        }
        static func mono(_ style: SwiftUI.Font.TextStyle, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(style, design: .monospaced).weight(weight)
        }
    }

    /// Bundled foreground+background pair for category-tinted surfaces.
    struct Palette: Equatable {
        let tile: SwiftUI.Color
        let icon: SwiftUI.Color

        static let purple = Palette(tile: Color.tilePurple, icon: Color.iconPurple)
        static let green = Palette(tile: Color.tileGreen, icon: Color.iconGreen)
        static let peach = Palette(tile: Color.tilePeach, icon: Color.iconPeach)
        static let blue = Palette(tile: Color.tileBlue, icon: Color.iconBlue)
        static let brown = Palette(tile: Color.tileBrown, icon: Color.iconBrown)
    }
}

// MARK: - Components

/// Rounded white card container with soft shadow.
struct DSCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(DS.Color.card)
            )
            .shadow(color: DS.Shadow.cardColor, radius: DS.Shadow.cardRadius, x: 0, y: DS.Shadow.cardY)
    }
}

/// Sentence-case section header for stacked card groups.
struct DSSectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(DS.Font.headline())
            .foregroundStyle(DS.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xs)
    }
}

/// Single row inside a DSCard with optional bottom divider.
struct DSRow<Content: View>: View {
    var showDivider: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)

            if showDivider {
                Rectangle()
                    .fill(DS.Color.divider)
                    .frame(height: 1)
            }
        }
    }
}

/// Rounded-rect tile icon used in timeline cards, settings rows, onboarding.
struct CategoryIcon: View {
    let symbol: String
    let palette: DS.Palette
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
            .fill(palette.tile)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(palette.icon)
            )
    }
}

/// Compact stat tile used on Route Detail and Insights screens.
struct StatCard: View {
    let symbol: String
    let palette: DS.Palette
    let value: String
    var unit: String? = nil
    let label: LocalizedStringKey

    var body: some View {
        DSCard(padding: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                CategoryIcon(symbol: symbol, palette: palette, size: 32)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(DS.Font.title())
                        .foregroundStyle(DS.Color.textPrimary)
                    if let unit {
                        Text(unit)
                            .font(DS.Font.caption(.medium))
                            .foregroundStyle(DS.Color.textMuted)
                    }
                }
                Text(label)
                    .font(DS.Font.caption())
                    .foregroundStyle(DS.Color.textMuted)
            }
        }
    }
}

/// Filled accent button for primary CTAs.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    var tint: Color = DS.Color.accent

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DS.Font.headline())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                        .fill(tint)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Bordered pill button used for secondary toggles (e.g., date selector).
struct PillButton: View {
    let title: LocalizedStringKey
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.body(.medium))
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(DS.Color.textPrimary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule().fill(DS.Color.card)
            )
            .overlay(
                Capsule().strokeBorder(DS.Color.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Tighter capsule used inline (e.g., "Today" date selector chip).
struct Chip: View {
    let title: LocalizedStringKey
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.body(.semibold))
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .foregroundStyle(DS.Color.textPrimary)
            .padding(.horizontal, DS.Spacing.sm + 2)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                    .fill(DS.Color.card)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Status indicator dot used on tracking and tab indicators.
struct StatusDot: View {
    enum State {
        case on, off, warning
    }
    let state: State
    var size: CGFloat = 8

    private var fill: Color {
        switch state {
        case .on: return DS.Color.accentGreen
        case .off: return DS.Color.dotInactive
        case .warning: return DS.Color.warning
        }
    }

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
    }
}
