import SwiftUI

struct LaneRushIntroView: View {
  @EnvironmentObject private var router: AppRouter
  @EnvironmentObject private var statistics: StatisticsStore
  private var descriptor: MiniGameDescriptor { LaneRushGameModule.descriptor }

  var body: some View {
    GameIntroLayout(
      descriptor: descriptor,
      statistics: statistics.statistics(for: descriptor.id),
      playHint: "Starts LANE RUSH immediately",
      onPlay: { router.startGame(descriptor.id) }
    ) {
      LaneRushPreviewIllustration()
    }
  }
}

private struct LaneRushPreviewIllustration: View {
  var body: some View {
    Canvas { context, size in
      let road = LaneRushStaticRoadGeometry(size: size)
      LaneRushRoadRenderer(
        size: size,
        vehicles: [
          LaneRushRenderedVehicle(
            id: 1, lane: .left, distanceAhead: 92,
            appearance: LaneRushVehicleAppearance(color: .cream, body: .coupe)),
          LaneRushRenderedVehicle(
            id: 2, lane: .right, distanceAhead: 72,
            appearance: LaneRushVehicleAppearance(color: .blue, body: .utility)),
          LaneRushRenderedVehicle(
            id: 3, lane: .center, distanceAhead: 49,
            appearance: LaneRushVehicleAppearance(color: .orange, body: .coupe)),
        ],
        roadMarkings: LaneRushRoadMarkingFlow().distancesAhead,
        playerPresentation: LaneRushPlayerController().presentation(on: road),
        score: 0,
        failureProgress: 0
      ).draw(in: &context)
    }
    .clipShape(RoundedRectangle(cornerRadius: 18))
  }
}

struct LaneRushCardIcon: View {
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.14))
      Path { path in
        path.move(to: CGPoint(x: 10, y: 39))
        path.addLine(to: CGPoint(x: 19, y: 12))
        path.move(to: CGPoint(x: 38, y: 39))
        path.addLine(to: CGPoint(x: 29, y: 12))
        path.move(to: CGPoint(x: 24, y: 38))
        path.addLine(to: CGPoint(x: 24, y: 14))
      }
      .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.cyan)
        .frame(width: 13, height: 9)
        .overlay(alignment: .top) {
          Rectangle().fill(Color.black.opacity(0.6)).frame(height: 3).padding(.horizontal, 2)
        }
        .offset(y: 9)
    }
    .frame(width: 48, height: 48)
  }
}
