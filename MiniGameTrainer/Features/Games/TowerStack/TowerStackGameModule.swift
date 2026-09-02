import SwiftUI

enum TowerStackGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "towerStack",
        name: "Tower Stack",
        subtitle: "Tap to drop sliding blocks onto a tower. Only the overlap survives.",
        instructions: "Tap to place each moving block. Only the overlapping part survives. The tower gets narrower when you miss the center, and blocks move faster as you climb. Stack as high as you can.",
        iconName: "square.stack.3d.up.fill",
        difficulty: .medium,
        skills: ["Timing", "Precision"]
    )

    static func makeIntroView() -> AnyView { AnyView(TowerStackIntroView()) }
    static func makeGameView() -> AnyView { AnyView(TowerStackGameView()) }
}
