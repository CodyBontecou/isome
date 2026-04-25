import SwiftUI

struct InsightsView: View {
    let viewModel: LocationViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(DS.Color.textMuted)
                    Text("Insights coming soon")
                        .font(DS.Font.title())
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Weekly stats, top places, and activity breakdowns will live here.")
                        .font(DS.Font.body())
                        .foregroundStyle(DS.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(DS.Spacing.xxl)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
