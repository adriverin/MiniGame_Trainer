import SwiftUI

enum JellyCutGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "jellyCut",
        name: "JELLY CUT",
        subtitle: "Slice each jelly as close as possible to the requested fraction.",
        instructions: """
        Swipe a straight line across the jelly to cut off the requested amount.

        Three rounds: half, one third, and one quarter.

        Your final score is your average precision.
        """,
        iconName: "scissors",
        difficulty: .medium,
        skills: ["Precision", "Spatial Reasoning", "Estimation"],
        scorePresentation: .precisionPercent
    )

    static func makeIntroView() -> AnyView { AnyView(JellyCutIntroView()) }
    static func makeGameView() -> AnyView { AnyView(JellyCutGameView()) }
}
