import SwiftUI
import UIKit

/// Teenage Engineering–inspired design tokens shared across all views.
enum TE {
    // MARK: - Colors
    /// Dynamic colors preserve the existing light palette and adapt across sheets and controls.
    static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let accent = adaptive(UIColor(red: 0.196, green: 0.455, blue: 0.956, alpha: 1),
                                 UIColor(red: 0.38, green: 0.62, blue: 1, alpha: 1))
    static let surface = adaptive(UIColor(red: 0.96, green: 0.955, blue: 0.94, alpha: 1),
                                  UIColor(red: 0.09, green: 0.09, blue: 0.085, alpha: 1))
    static let surfaceDark = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let card = adaptive(.white, UIColor(red: 0.14, green: 0.14, blue: 0.135, alpha: 1))
    static let border = adaptive(UIColor(red: 0.82, green: 0.81, blue: 0.79, alpha: 1),
                                 UIColor(red: 0.30, green: 0.30, blue: 0.28, alpha: 1))
    static let borderDark = Color(red: 0.25, green: 0.25, blue: 0.25)
    static let textPrimary = adaptive(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1),
                                      UIColor(red: 0.95, green: 0.95, blue: 0.93, alpha: 1))
    static let textMuted = adaptive(UIColor(red: 0.44, green: 0.43, blue: 0.41, alpha: 1),
                                    UIColor(red: 0.68, green: 0.67, blue: 0.64, alpha: 1))
    static let lcdGreen = Color(red: 0.0, green: 0.78, blue: 0.45)
    static let lcdBackground = adaptive(UIColor(red: 0.88, green: 0.90, blue: 0.85, alpha: 1),
                                        UIColor(red: 0.17, green: 0.21, blue: 0.17, alpha: 1))
    static let danger = Color(uiColor: .systemRed)
    static let warning = Color(uiColor: .systemOrange)
    static let success = Color(uiColor: .systemGreen)

    // MARK: - Typography
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style, design: .monospaced).weight(weight)
    }
}

// MARK: - Illustrated onboarding and purchase flow

/// Kept separate from TE so the rest of the app retains its existing appearance.
enum InkPaperPalette {
    static let ink = TE.adaptive(
        UIColor(red: 0.14, green: 0.27, blue: 0.62, alpha: 1),
        UIColor(red: 0.58, green: 0.70, blue: 1, alpha: 1)
    )
    static let paper = TE.adaptive(
        UIColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1),
        UIColor(red: 0.09, green: 0.11, blue: 0.15, alpha: 1)
    )
    static let pencil = TE.adaptive(
        UIColor(red: 0.39, green: 0.39, blue: 0.38, alpha: 1),
        UIColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1)
    )
    static let wash = ink.opacity(0.045)
    static let border = ink.opacity(0.24)
}

// MARK: - Reusable Components

/// TE-styled section header: uppercase, tracked, monospaced.
struct TESectionHeader: View {
    let title: LocalizedStringKey
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Text(title)
            .font(TE.mono(.caption2, weight: .semibold))
            .tracking(dynamicTypeSize.isAccessibilitySize ? 1 : 2)
            .foregroundStyle(TE.textMuted)
            .fixedSize(horizontal: false, vertical: true)
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

/// TE-styled toggle: cream-paper-friendly off track with stronger border,
/// solid accent on track. Gives clear contrast on TE.surface backgrounds.
struct TEToggleStyle: ToggleStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var trackWidth: CGFloat = 50
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var thumbInset: CGFloat = 2

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        let thumbDiameter = trackHeight - thumbInset * 2

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)

                toggleTrack(isOn: isOn, thumbDiameter: thumbDiameter)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                configuration.isOn.toggle()
            }
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                toggleTrack(isOn: isOn, thumbDiameter: thumbDiameter)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                configuration.isOn.toggle()
            }
            .accessibilityRepresentation {
                Toggle(isOn: configuration.$isOn) { configuration.label }
            }
        }
    }

    private func toggleTrack(isOn: Bool, thumbDiameter: CGFloat) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? TE.accent : TE.border)
            Capsule()
                .strokeBorder(isOn ? TE.accent : TE.textMuted.opacity(0.35), lineWidth: 1)

            Circle()
                .fill(Color.white)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
                .padding(.horizontal, thumbInset)
        }
        .frame(width: trackWidth, height: trackHeight)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isOn)
    }
}

/// TE-styled section footer text.
struct TESectionFooter: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(TE.mono(.caption2, weight: .regular))
            .foregroundStyle(TE.textMuted)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }
}

/// Stored as a raw value so an unknown preference safely falls back to the system.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}


/// Decorative ink sketches sit behind the flow, never reserving header space.
struct InkJournalBackground: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                InkPaperPalette.paper
                VStack(spacing: 0) {
                    sketch("JournalClouds")
                        .frame(height: min(geometry.size.height * 0.38, 320))
                        .opacity(dynamicTypeSize.isAccessibilitySize ? 0.15 : 0.30)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.6), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
                    Spacer(minLength: 0)
                    sketch("JournalStreet")
                        .frame(height: min(geometry.size.height * 0.48, 400))
                        .opacity(dynamicTypeSize.isAccessibilitySize ? 0.16 : 0.42)
                }
                InkPaperGrain(ink: InkPaperPalette.ink)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sketch(_ name: String) -> some View {
        GeometryReader { geometry in
            Image(decorative: name)
                .renderingMode(.template)
                .resizable()
                .scaledToFill()
                .foregroundStyle(InkPaperPalette.ink)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}
