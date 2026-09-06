import SwiftUI

enum ZigGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "zig",
        name: "ZIG",
        subtitle: "Change direction at every bend and stay on the path.",
        instructions: """
        Tap anywhere to change the ball's direction. Stay on the path for as long as you can.

        The ball gets faster as your score rises.

        Leave the path and the run ends.
        """,
        iconName: "point.topleft.down.to.point.bottomright.curvepath.fill",
        difficulty: .hard,
        skills: ["Timing", "Reflexes", "Precision"],
        scorePresentation: ScorePresentation(label: "Distance")
    )

    static func makeIntroView() -> AnyView { AnyView(ZigIntroView()) }
    static func makeGameView() -> AnyView { AnyView(ZigGameView()) }
}
