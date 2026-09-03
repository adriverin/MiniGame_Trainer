import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text("PRO")
                            .font(AppTheme.Fonts.title)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Unlimited attempts. No ads.")
                            .font(AppTheme.Fonts.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            benefitRow("Unlimited attempts in every game")
                            benefitRow("No rewarded-ad prompts")
                        }
                    }

                    productSection
                    statusSection

                    Button("Restore Purchases") {
                        Task { await purchases.restore() }
                    }
                    .font(AppTheme.Fonts.button)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .disabled(purchases.isBusy)

                    LegalLinkButtons()
                        .padding(.top, 4)
                }
                .padding(AppTheme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") {
                    router.dismissPaywall()
                }
            }
        }
        .onAppear {
            switch purchases.catalogState {
            case .idle, .failed:
                Task { await purchases.loadProducts() }
            case .loading, .loaded:
                break
            }
        }
        .onChange(of: purchases.isPro) { _, isPro in
            if isPro {
                router.dismissPaywall()
            }
        }
    }

    @ViewBuilder
    private var productSection: some View {
        switch purchases.catalogState {
        case .idle, .loading:
            ProgressView()
                .tint(AppTheme.Colors.accent)
                .padding(.vertical, 12)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message.isEmpty ? "Subscriptions are unavailable right now." : message)
                    .font(AppTheme.Fonts.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise") {
                    Task { await purchases.loadProducts() }
                }
            }
        case .loaded:
            VStack(spacing: 12) {
                if let yearly = purchases.yearlyProduct {
                    productCard(yearly, highlight: true, subtitle: "Annual")
                }
                if let monthly = purchases.monthlyProduct {
                    productCard(monthly, highlight: false, subtitle: "Monthly")
                }
                if purchases.yearlyProduct == nil && purchases.monthlyProduct == nil {
                    Text("Subscriptions are unavailable right now.")
                        .font(AppTheme.Fonts.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    PrimaryButton(title: "Try Again", systemImage: "arrow.clockwise") {
                        Task { await purchases.loadProducts() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch purchases.actionState {
        case .idle:
            EmptyView()
        case .purchasing:
            Text("Purchasing…")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        case .pending:
            Text("Purchase is pending approval.")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.warning)
        case .failed(let message):
            Text(message)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.warning)
                .multilineTextAlignment(.center)
        case .cancelled:
            EmptyView()
        case .restoring:
            Text("Restoring purchases…")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        case .restored:
            Text(purchases.isPro ? "Pro is active." : "No active Pro subscription found.")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func productCard(_ product: StoreProduct, highlight: Bool, subtitle: String) -> some View {
        Button {
            Task { await purchases.purchase(product) }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(highlight ? "Annual Pro" : "Monthly Pro")
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Text(product.displayPrice)
                        .font(AppTheme.Fonts.heading)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                Text(subtitle)
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(highlight ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius, style: .continuous)
                    .fill(highlight ? AppTheme.Colors.surfaceElevated : AppTheme.Colors.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(highlight ? AppTheme.Colors.accent.opacity(0.7) : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(purchases.isBusy || purchases.isPro)
        .accessibilityLabel("\(highlight ? "Annual Pro" : "Monthly Pro") \(product.displayPrice)")
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Colors.success)
            Text(text)
                .font(AppTheme.Fonts.body)
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
        }
    }
}
