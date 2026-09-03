import SwiftUI

enum SwipeFastGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "swipeFast",
        name: "Swipe Fast",
        subtitle: "Four boxes. Four arrows. Keep every timer alive.",
        instructions: "Four boxes. Four arrows.\n\nSwipe each box in the direction shown.\nKeep every box alive and react quickly.\nThe pace gets faster as your score rises.\n\nHigher score is better.",
        iconName: "square.grid.2x2.fill",
        difficulty: .hard,
        skills: ["Reaction", "Multitasking", "Direction"]
    )

    static func makeIntroView() -> AnyView { AnyView(SwipeFastIntroView()) }
    static func makeGameView() -> AnyView { AnyView(SwipeFastGameView()) }
}
