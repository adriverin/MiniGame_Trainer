import SwiftUI

enum JumpyGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "jumpy",
        name: "JUMPY",
        subtitle: "Hop through moving traffic and climb as far as you can.",
        instructions: """
        Tap to jump forward. Swipe to jump left, right, up, or down. Cross the moving traffic and keep climbing.

        Your score is your greatest forward distance.

        One collision ends the run.
        """,
        iconName: "arrow.up.and.down.and.arrow.left.and.right",
        difficulty: .medium,
        skills: ["Timing", "Prediction", "Spatial Awareness"],
        scorePresentation: ScorePresentation(label: "Distance")
    )

    static func makeIntroView() -> AnyView { AnyView(JumpyIntroView()) }
    static func makeGameView() -> AnyView { AnyView(JumpyGameView()) }
}
