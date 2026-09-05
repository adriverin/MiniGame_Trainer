import SwiftUI

enum TraceGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "trace",
        name: "Trace",
        subtitle: "Memorize the path, then drag it back from memory.",
        instructions: "Memorize the path. When it disappears, drag through the dots to recreate it. Patterns become harder as you progress. Higher score is better.",
        iconName: "scribble.variable",
        difficulty: .hard,
        skills: ["Memory", "Sequencing", "Motor Control"]
    )

    static func makeIntroView() -> AnyView { AnyView(TraceIntroView()) }
    static func makeGameView() -> AnyView { AnyView(TraceGameView()) }
}
