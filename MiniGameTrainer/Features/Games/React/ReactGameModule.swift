import SwiftUI

enum ReactGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "react",
        name: "REACT!",
        subtitle: "Tap the illuminated circle as quickly as you can. Lower reaction time is better.",
        instructions: "Tap the circle as soon as it lights up. Each target appears after a random delay. Your average reaction time is your score. Lower is better.",
        iconName: "circle.grid.3x3.fill",
        difficulty: .easy,
        skills: ["Visual Reaction", "Accuracy"],
        scorePresentation: .reactionMilliseconds
    )

    static func makeIntroView() -> AnyView { AnyView(ReactIntroView()) }
    static func makeGameView() -> AnyView { AnyView(ReactGameView()) }
}
