import SwiftUI

enum DirectionsGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "directions",
        name: "Directions",
        subtitle: "Watch the arrows, then reproduce the sequence.",
        instructions: "Watch the arrows. Remember their order. When it's your turn, reproduce the sequence using the direction buttons. Sequences get harder as you progress. Higher score is better.",
        iconName: "dpad",
        difficulty: .medium,
        skills: ["Working memory", "Sequence", "Recall"]
    )

    static func makeIntroView() -> AnyView { AnyView(DirectionsIntroView()) }
    static func makeGameView() -> AnyView { AnyView(DirectionsGameView()) }
}
