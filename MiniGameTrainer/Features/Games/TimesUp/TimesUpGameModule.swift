import SwiftUI

enum TimesUpGameModule: MiniGameModule {
    static let descriptor = MiniGameDescriptor(
        id: "timesUp",
        name: "TIME'S UP!",
        subtitle: "Watch the bar drain, then tap when you think the full time has elapsed. Lower error is better.",
        instructions: "Watch the progress bar drain. Halfway through, it disappears. Tap when you think the full time has elapsed. Your average timing error is your score. Lower is better. 3 rounds.",
        iconName: "hourglass",
        difficulty: .medium,
        skills: ["Time estimation", "Internal clock"],
        scorePresentation: .timingErrorSeconds
    )

    static func makeIntroView() -> AnyView { AnyView(TimesUpIntroView()) }
    static func makeGameView() -> AnyView { AnyView(TimesUpGameView()) }
}
