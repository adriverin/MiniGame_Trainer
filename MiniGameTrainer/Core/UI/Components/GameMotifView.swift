import SwiftUI

struct GameIconView: View {
    let descriptor: MiniGameDescriptor
    let theme: GameVisualTheme
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: descriptor.iconName)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(theme.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: theme.primary.opacity(0.22), radius: 12, y: 5)
            .accessibilityHidden(true)
    }
}

/// A low-cost, non-animated motif that adds identity without competing with content.
struct GameMotifBackground: View {
    let theme: GameVisualTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.gradient.opacity(0.14)

                Circle()
                    .fill(theme.primary.opacity(0.15))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 28)
                    .offset(x: proxy.size.width * 0.30, y: -proxy.size.height * 0.18)

                motif(in: proxy.size)
                    .foregroundStyle(theme.primary.opacity(0.22))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func motif(in size: CGSize) -> some View {
        switch theme.motif {
        case .keys:
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: 22, height: index.isMultiple(of: 2) ? 86 : 62)
                }
            }
            .rotationEffect(.degrees(-8))
            .offset(x: size.width * 0.24, y: size.height * 0.10)
        case .stack:
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .frame(width: 126 - CGFloat(index) * 19, height: 24)
                }
            }
            .rotationEffect(.degrees(-5))
            .offset(x: size.width * 0.27, y: size.height * 0.10)
        case .grid:
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .opacity([1, 3, 7].contains(index) ? 1 : 0.35)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: 100)
            .rotationEffect(.degrees(8))
            .offset(x: size.width * 0.28)
        case .target, .speed:
            ZStack {
                ForEach(1..<4, id: \.self) { ring in
                    Circle().stroke(lineWidth: 6).frame(width: CGFloat(ring) * 38)
                }
                Circle().frame(width: 20, height: 20)
            }
            .offset(x: size.width * 0.28)
        case .timer:
            Image(systemName: "timer")
                .font(.system(size: 112, weight: .thin))
                .offset(x: size.width * 0.28)
        case .lanes:
            HStack(spacing: 34) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().frame(width: 6, height: size.height * 1.4)
                }
            }
            .rotationEffect(.degrees(13))
            .offset(x: size.width * 0.28)
        case .split:
            ZStack {
                Circle().frame(width: 116, height: 116).offset(x: -12)
                Capsule().fill(AppTheme.Colors.background).frame(width: 8, height: 150).rotationEffect(.degrees(28))
            }
            .offset(x: size.width * 0.28)
        case .zig, .path:
            Image(systemName: theme.motif == .zig ? "point.topleft.down.to.point.bottomright.curvepath.fill" : "scribble.variable")
                .font(.system(size: 108, weight: .semibold))
                .rotationEffect(.degrees(-8))
                .offset(x: size.width * 0.28)
        case .arrows, .swipe, .jump:
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 94, weight: .bold))
                .rotationEffect(.degrees(8))
                .offset(x: size.width * 0.28)
        case .bounce, .orbit, .climb:
            ZStack {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(lineWidth: 5)
                        .frame(width: 34 + CGFloat(index) * 29)
                        .offset(x: CGFloat(index) * 11, y: -CGFloat(index) * 8)
                }
            }
            .offset(x: size.width * 0.25)
        case .burst, .color:
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Capsule()
                        .frame(width: 7, height: 58)
                        .offset(y: -56)
                        .rotationEffect(.degrees(Double(index) * 45))
                }
                Circle().frame(width: 40, height: 40)
            }
            .offset(x: size.width * 0.28)
        }
    }
}
