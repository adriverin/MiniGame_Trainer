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
        .navigationTitle("")
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
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(AppInfo.name)
                    .font(AppTheme.Fonts.brand)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Beat your best.")
                    .font(AppTheme.Fonts.secondary.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer(minLength: AppTheme.Spacing.md)
            if purchases.isPro { StatusBadge(title: "Pro") }
        }
        .padding(.top, AppTheme.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}
