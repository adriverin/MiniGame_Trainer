import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedProductID: String?

    private var selectedProduct: StoreProduct? {
        guard let selectedProductID else { return nil }
        return [purchases.yearlyProduct, purchases.monthlyProduct]
            .compactMap { $0 }.first { $0.id == selectedProductID }
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        StatusBadge(title: purchases.isPro ? "Pro Active" : "Pro", systemImage: "sparkles")
                        Text("\(AppInfo.name) Pro")
                            .font(AppTheme.Fonts.title)
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(purchases.isPro ? "Your next personal best is waiting." : "Keep playing. Keep improving.")
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

                    if purchases.isPro {
                        CardContainer {
                            VStack(spacing: AppTheme.Spacing.md) {
                                StatusBadge(title: "Unlimited Attempts", systemImage: "infinity", color: AppTheme.Colors.success)
                                Text("Pro is active in every game.")
                                    .font(AppTheme.Fonts.body)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        PrimaryButton(title: "Continue Playing", systemImage: "play.fill") {
                            router.dismissPaywall()
                        }
                    } else {
                        productSection
                        if let product = selectedProduct {
                            PrimaryButton(title: "Subscribe · \(product.displayPrice) / \(product.isYearly ? "year" : "month")") {
                                Task { await purchases.purchase(product) }
                            }
                            .disabled(purchases.isBusy)
                            .accessibilityIdentifier("subscribe")
                        } else if purchases.yearlyProduct != nil || purchases.monthlyProduct != nil {
                            PrimaryButton(title: "Choose a Plan") {}
                                .disabled(true)
                        }
                        if purchases.yearlyProduct != nil || purchases.monthlyProduct != nil {
                            Text("Auto-renews until cancelled. Manage or cancel in your App Store account settings.")
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    statusSection

                    Button("Restore Purchases") {
                        Task { await purchases.restore() }
                    }
                    .font(AppTheme.Fonts.button)
                    .frame(minHeight: 44)
                    .foregroundStyle(AppTheme.Colors.accent)
                    .disabled(purchases.isBusy)

                    LegalLinkButtons()
                        .padding(.top, 4)
                }
                .padding(AppTheme.Metrics.screenPadding)
                .frame(maxWidth: AppTheme.Metrics.contentWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Pro")
        .navigationBarBackButtonHidden(true)
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
            ProgressView("Loading plans…")
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
                Text("Choose your plan")
                    .font(AppTheme.Fonts.cardTitle)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let yearly = purchases.yearlyProduct {
                    productCard(yearly)
                }
                if let monthly = purchases.monthlyProduct {
                    productCard(monthly)
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

    private func productCard(_ product: StoreProduct) -> some View {
        let isSelected = selectedProductID == product.id
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                selectedProductID = product.id
            }
        } label: {
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.textSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(product.isYearly ? "Annual" : "Monthly")
                        .font(AppTheme.Fonts.cardTitle)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("\(product.displayPrice) / \(product.isYearly ? "year" : "month")")
                        .font(AppTheme.Fonts.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(product.isYearly ? "Billed once a year" : "Billed every month")
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(AppTheme.Metrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.Colors.surfaceElevated : AppTheme.Colors.surface,
                        in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                    .strokeBorder(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.divider,
                                  lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(ShellPressStyle())
        .disabled(purchases.isBusy || purchases.isPro)
        .accessibilityLabel("\(product.isYearly ? "Annual" : "Monthly") Pro, \(product.displayPrice) per \(product.isYearly ? "year" : "month")")
        .accessibilityHint("Selects this subscription plan")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(product.isYearly ? "plan.annual" : "plan.monthly")
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
