import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    GameLibraryView()
                    Text(AppInfo.disclaimer)
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 12)
                }
                .padding(AppTheme.Metrics.screenPadding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.showSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppInfo.name)
                .font(AppTheme.Fonts.title)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(AppInfo.tagline)
                .font(AppTheme.Fonts.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}
