import SwiftUI

enum KeepUpGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "keepUp",
        name: "Keep Up",
        subtitle: "Track the falling ball and catch it with the circular platform.",
        instructions: "Drag in any direction to keep the platform under the ball. Each successful bounce scores one point. Miss once and the run is over.",
        iconName: "circle.bottomhalf.filled",
        difficulty: .medium,
        skills: ["Prediction", "Tracking", "Positioning"]
    )

    static func makeIntroView() -> AnyView { AnyView(KeepUpIntroView()) }
    static func makeGameView() -> AnyView { AnyView(KeepUpGameView()) }
}
