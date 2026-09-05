import SwiftUI

enum TapSevenGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "tapSeven",
        name: "TAP AT 7",
        subtitle: "Watch the timer. Tap as close as possible to exactly 7 seconds. Lower error is better.",
        instructions: "Watch the timer. Tap as close as possible to exactly 7 seconds. Your timing error is your score. Lower is better.",
        iconName: "timer",
        difficulty: .medium,
        skills: ["Timing", "Precision", "Visual Tracking"],
        scorePresentation: TapSevenGameConfig.scorePresentation
    )

    static func makeIntroView() -> AnyView { AnyView(TapSevenIntroView()) }
    static func makeGameView() -> AnyView { AnyView(TapSevenGameView()) }
}
