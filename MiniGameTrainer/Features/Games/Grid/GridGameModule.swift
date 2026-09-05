import SwiftUI

enum GridGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "grid",
        name: "GRID",
        subtitle: "Remember the highlighted cells and recreate the pattern.",
        instructions: "Memorize the highlighted cells. When they disappear, recreate the pattern from memory. Submit your answer before time runs out. Patterns get harder as you progress.",
        iconName: "square.grid.3x3.fill",
        difficulty: .medium,
        skills: ["Working Memory", "Spatial Recall", "Attention"],
        scorePresentation: .points
    )

    static func makeIntroView() -> AnyView { AnyView(GridIntroView()) }
    static func makeGameView() -> AnyView { AnyView(GridGameView()) }
}
