import SwiftUI

enum BloopyGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "bloopy",
        name: "Bloopy",
        subtitle: "Steer the bouncing ball and climb through wrapping platforms.",
        instructions: "Tap left or right to steer while the ball bounces automatically. The world wraps at the sides — leave one edge and you'll reappear at the other. Keep landing on platforms and climb as high as you can. Higher score is better.",
        iconName: "circle.hexagonpath.fill",
        difficulty: .medium,
        skills: ["Steering", "Timing", "Spatial Wrap"]
    )

    static func makeIntroView() -> AnyView { AnyView(BloopyIntroView()) }
    static func makeGameView() -> AnyView { AnyView(BloopyGameView()) }
}
