import SwiftUI

enum TrampboxGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "trampbox",
        name: "Trampbox",
        subtitle: "Steer an automatically bouncing ball across a narrowing path of platforms.",
        instructions: "Drag left and right to guide the bouncing ball onto the next platform. The bounces get faster and the platforms get narrower as you progress.",
        iconName: "circle.grid.cross",
        difficulty: .hard,
        skills: ["Steering", "Precision"]
    )

    static func makeIntroView() -> AnyView { AnyView(TrampboxIntroView()) }
    static func makeGameView() -> AnyView { AnyView(TrampboxGameView()) }
}
