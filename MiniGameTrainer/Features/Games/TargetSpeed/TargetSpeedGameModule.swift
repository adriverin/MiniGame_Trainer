import SwiftUI

enum TargetSpeedGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "targetSpeed",
        name: "Target Speed",
        subtitle: "Tap every target before it disappears.",
        instructions: "Tap each target before it disappears.\n\nTargets get smaller and more numerous as your score rises.\nMiss a target and lose a life.\nYou have 3 lives.\n\nHigher score is better.",
        iconName: "target",
        difficulty: .hard,
        skills: ["Reaction", "Accuracy", "Multitasking"]
    )

    static func makeIntroView() -> AnyView { AnyView(TargetSpeedIntroView()) }
    static func makeGameView() -> AnyView { AnyView(TargetSpeedGameView()) }
}
