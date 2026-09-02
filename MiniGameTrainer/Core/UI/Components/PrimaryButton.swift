import SwiftUI

struct PrimaryButton: View {
    enum Style {
        case filled
        case outlined
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .filled
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(AppTheme.Fonts.button)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(style == .filled ? Color.black.opacity(0.85) : AppTheme.Colors.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(style == .filled ? AppTheme.Colors.textPrimary : Color.clear)
            }
            .overlay {
                if style == .outlined {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
