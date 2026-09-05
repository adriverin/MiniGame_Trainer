import SwiftUI

enum CenterHitGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "centerHit",
        name: "Center Hit",
        subtitle: "Tap as the bouncing line reaches the exact center. It accelerates every time.",
        instructions: "A line moves back and forth across the bar. Tap when it reaches the exact center. It gets faster after every attempt. Your average precision is your score. 5 attempts.",
        iconName: "scope",
        difficulty: .medium,
        skills: ["Visual Timing", "Prediction", "Precision"],
        scorePresentation: .precisionPercent
    )

    static func makeIntroView() -> AnyView { AnyView(CenterHitIntroView()) }
    static func makeGameView() -> AnyView { AnyView(CenterHitGameView()) }
}
