import SwiftUI

struct JellyCutIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    private var descriptor: MiniGameDescriptor { JellyCutGameModule.descriptor }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: statistics.statistics(for: descriptor.id),
            playHint: "Starts a three-round JELLY CUT session",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            JellyCutPreviewIllustration()
        }
    }
}

struct JellyCutPreviewIllustration: View {
    private let leftPiece = [
        CGPoint(x: 0.13, y: 0.72), CGPoint(x: 0.20, y: 0.28), CGPoint(x: 0.34, y: 0.18),
        CGPoint(x: 0.48, y: 0.25), CGPoint(x: 0.49, y: 0.78), CGPoint(x: 0.35, y: 0.86),
    ]
    private let rightPiece = [
        CGPoint(x: 0.53, y: 0.25), CGPoint(x: 0.67, y: 0.18), CGPoint(x: 0.86, y: 0.34),
        CGPoint(x: 0.88, y: 0.70), CGPoint(x: 0.70, y: 0.87), CGPoint(x: 0.52, y: 0.78),
    ]

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 1, green: 0.20, blue: 0.58), Color(red: 0.73, green: 0.03, blue: 0.36)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
            ))
            let shadowRect = CGRect(x: size.width * 0.22, y: size.height * 0.78, width: size.width * 0.56, height: size.height * 0.10)
            context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.22)))
            draw(leftPiece, offsetX: -0.012, in: &context, size: size, color: Color(red: 1, green: 0.70, blue: 0.15))
            draw(rightPiece, offsetX: 0.012, in: &context, size: size, color: Color(red: 0.12, green: 0.93, blue: 0.61))
            var cut = Path()
            cut.move(to: CGPoint(x: size.width * 0.505, y: size.height * 0.14))
            cut.addLine(to: CGPoint(x: size.width * 0.505, y: size.height * 0.88))
            context.stroke(cut, with: .color(.white.opacity(0.95)), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func draw(
        _ points: [CGPoint], offsetX: CGFloat, in context: inout GraphicsContext,
        size: CGSize, color: Color
    ) {
        var path = Path()
        guard let first = points.first else { return }
        path.move(to: CGPoint(x: (first.x + offsetX) * size.width, y: first.y * size.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: (point.x + offsetX) * size.width, y: point.y * size.height))
        }
        path.closeSubpath()
        context.fill(path, with: .linearGradient(
            Gradient(colors: [color.opacity(0.82), color]),
            startPoint: CGPoint(x: 0, y: size.height * 0.15),
            endPoint: CGPoint(x: 0, y: size.height * 0.85)
        ))
        context.stroke(path, with: .color(Color(red: 0.02, green: 0.52, blue: 0.39)), lineWidth: 3)
    }
}

struct JellyCutCardIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.pink.opacity(0.15))
            Path { path in
                path.move(to: CGPoint(x: 8, y: 29)); path.addCurve(
                    to: CGPoint(x: 39, y: 27), control1: CGPoint(x: 10, y: 10), control2: CGPoint(x: 34, y: 9)
                )
                path.addCurve(to: CGPoint(x: 8, y: 29), control1: CGPoint(x: 42, y: 42), control2: CGPoint(x: 15, y: 42))
            }
            .fill(Color(red: 0.12, green: 0.93, blue: 0.61))
            .overlay {
                Path { path in
                    path.move(to: CGPoint(x: 5, y: 39)); path.addLine(to: CGPoint(x: 42, y: 8))
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 3]))
            }
        }
        .frame(width: 48, height: 48)
    }
}
