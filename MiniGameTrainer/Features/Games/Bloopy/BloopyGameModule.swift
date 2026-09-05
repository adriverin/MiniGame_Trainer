import SwiftUI

enum BloopyGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "bloopy",
        name: "Bloopy",
        subtitle: "Steer the bouncing ball and climb as high as you can.",
        instructions: "Tap left or right to steer while the ball bounces automatically. Keep climbing as high as you can. Higher score is better.",
        iconName: "circle.hexagonpath.fill",
        difficulty: .medium,
        skills: ["Steering", "Timing", "Climbing"]
    )

    static func makeIntroView() -> AnyView { AnyView(BloopyIntroView()) }
    static func makeGameView() -> AnyView { AnyView(BloopyGameView()) }
}
