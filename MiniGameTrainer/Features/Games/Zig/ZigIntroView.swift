import SwiftUI

struct ZigIntroView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var statistics: StatisticsStore
    @ObservedObject private var tuning = ZigTuningStore.shared
    private var descriptor: MiniGameDescriptor { ZigGameModule.descriptor }

    var body: some View {
        GameIntroLayout(
            descriptor: descriptor,
            statistics: statistics.statistics(for: descriptor.id),
            playHint: "Starts ZIG immediately",
            onPlay: { router.startGame(descriptor.id) }
        ) {
            ZigPreviewIllustration(config: tuning.config)
        }
    }
}

struct ZigPreviewIllustration: View {
    let config: ZigGameConfig

    var body: some View {
        Canvas { context, size in
            let background = Path(CGRect(origin: .zero, size: size))
            context.fill(background, with: .linearGradient(
                Gradient(colors: [Color(config.backgroundBottomColor), Color(config.backgroundTopColor)]),
                startPoint: CGPoint(x: 0, y: size.height), endPoint: .zero
            ))
            let points = [
                CGPoint(x: size.width * 0.12, y: size.height * 0.82),
                CGPoint(x: size.width * 0.43, y: size.height * 0.67),
                CGPoint(x: size.width * 0.27, y: size.height * 0.55),
                CGPoint(x: size.width * 0.58, y: size.height * 0.40),
                CGPoint(x: size.width * 0.43, y: size.height * 0.28),
                CGPoint(x: size.width * 0.72, y: size.height * 0.14),
            ]
            var side = Path()
            side.addLines(points)
            let lowered = points.reversed().map { CGPoint(x: $0.x, y: $0.y + size.height * 0.15) }
            side.addLines(lowered)
            side.closeSubpath()
            context.stroke(side, with: .color(Color(config.rightSideColor)), style: StrokeStyle(lineWidth: size.width * 0.11, lineCap: .butt, lineJoin: .miter))
            var top = Path(); top.addLines(points)
            context.stroke(top, with: .color(Color(config.topColor)), style: StrokeStyle(lineWidth: size.width * 0.12, lineCap: .butt, lineJoin: .miter))
            let ball = CGRect(x: size.width * 0.405, y: size.height * 0.62, width: size.width * 0.055, height: size.width * 0.055)
            context.fill(Path(ellipseIn: ball), with: .color(Color(config.ballColor)))
            _ = lowered
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct ZigCardIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.16))
            Path { path in
                path.move(to: CGPoint(x: 8, y: 34)); path.addLine(to: CGPoint(x: 23, y: 25))
                path.addLine(to: CGPoint(x: 14, y: 18)); path.addLine(to: CGPoint(x: 32, y: 9))
            }
            .stroke(Color.yellow, style: StrokeStyle(lineWidth: 7, lineCap: .butt, lineJoin: .miter))
            Circle().fill(Color.black.opacity(0.88)).frame(width: 7, height: 7).offset(x: 3, y: 3)
        }
        .frame(width: 48, height: 48)
    }
}
