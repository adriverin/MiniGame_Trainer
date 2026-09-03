import SwiftUI

enum ColorReflexGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "colorReflex",
        name: "Color Reflex",
        subtitle: "Wait for the color to change, then tap. Don't tap too early.",
        instructions: """
        Wait for the background color to change.

        When it changes, tap as quickly as possible.

        Tap too early and you'll lose time.

        Score as many reactions as you can before time runs out.

        Higher score is better.
        """,
        iconName: "paintpalette.fill",
        difficulty: .medium,
        skills: ["Reaction", "Inhibition", "Focus"]
    )

    static func makeIntroView() -> AnyView { AnyView(ColorReflexIntroView()) }
    static func makeGameView() -> AnyView { AnyView(ColorReflexGameView()) }
}
