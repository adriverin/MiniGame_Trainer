import SwiftUI

enum LaneRushGameModule: MiniGameModule {
  static let descriptor = MiniGameDescriptor(
    id: "laneRush",
    name: "LANE RUSH",
    subtitle: "Dodge oncoming traffic and travel as far as you can.",
    instructions: """
      Tap either side or swipe left and right to change lanes.

      Dodge the oncoming traffic and travel as far as you can.

      One collision ends the run.
      """,
    iconName: "car.fill",
    difficulty: .hard,
    skills: ["Reaction", "Timing", "Prediction"],
    scorePresentation: ScorePresentation(label: "Distance", unit: "m")
  )

  static func makeIntroView() -> AnyView { AnyView(LaneRushIntroView()) }
  static func makeGameView() -> AnyView { AnyView(LaneRushGameView()) }
}
