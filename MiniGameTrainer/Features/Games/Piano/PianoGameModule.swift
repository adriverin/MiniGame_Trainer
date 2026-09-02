import SwiftUI

/// Registry entry for the Piano game. This is the only type the app shell needs to know about.
enum PianoGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "piano",
        name: "Piano",
        subtitle: "Tap every white tile before it slides past the miss line. One mistake ends the run.",
        instructions: "White tiles scroll down four lanes. Tap each one as quickly and accurately as possible. Miss a tile or tap an empty lane and the game is over.",
        iconName: "pianokeys",
        difficulty: .medium,
        skills: ["Reaction", "Timing"]
    )

    static func makeIntroView() -> AnyView {
        AnyView(PianoIntroView())
    }

    static func makeGameView() -> AnyView {
        AnyView(PianoGameView())
    }
}
