import SwiftUI

struct TimelineView: View {
    let viewModel: LocationViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Color.background.ignoresSafeArea()

                VStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48, weight: .regular))
                        .foregroundStyle(DS.Color.textMuted)
                    Text("Timeline coming soon")
                        .font(DS.Font.title())
                        .foregroundStyle(DS.Color.textPrimary)
                    Text("Today's visits and routes will appear here.")
                        .font(DS.Font.body())
                        .foregroundStyle(DS.Color.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(DS.Spacing.xxl)
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
