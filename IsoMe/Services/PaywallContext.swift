// Presentation-only context; never recorded or uploaded.
nonisolated enum PaywallContext: String, CaseIterable, Sendable {
    case export
    case settings
    case webhook
    case onboarding
}
