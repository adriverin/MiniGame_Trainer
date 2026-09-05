import SwiftUI

struct PrimaryButton: View {
    enum Style {
        case filled
        case outlined
        case quiet
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .filled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage).accessibilityHidden(true)
                }
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
            .font(AppTheme.Fonts.button)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.controlHeight)
            .foregroundStyle(style == .filled ? AppTheme.Colors.background : AppTheme.Colors.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                    .fill(style == .filled ? AppTheme.Colors.accent :
                            style == .outlined ? AppTheme.Colors.surface : Color.clear)
            }
            .overlay {
                if style == .outlined {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                        .strokeBorder(AppTheme.Colors.divider, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        }
        .buttonStyle(ShellPressStyle())
        .accessibilityLabel(title)
    }
}

/// Shared feedback without continuous animation, and with an explicit disabled state.
struct ShellPressStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
