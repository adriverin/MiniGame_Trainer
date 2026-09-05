import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    header
                    GameLibraryView()
                    Text(AppInfo.disclaimer)
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, AppTheme.Spacing.md)
                }
                .padding(AppTheme.Metrics.screenPadding)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.showSettings() } label: {
                    Image(systemName: "gearshape")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(AppInfo.name)
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                if purchases.isPro { StatusBadge(title: "Pro") }
            }
            Text("Small games.\nPersonal bests.")
                .font(AppTheme.Fonts.heading)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(AppInfo.tagline)
                .font(AppTheme.Fonts.secondary)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
