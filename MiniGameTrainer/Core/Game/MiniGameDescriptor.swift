import Foundation

/// Static metadata describing a minigame for the library, intro and statistics screens.
struct MiniGameDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    /// One-line description shown on the game card.
    let subtitle: String
    /// Short instructions shown on the intro screen.
    let instructions: String
    /// SF Symbol name used as the game icon.
    let iconName: String
    let difficulty: GameDifficulty
    /// Skills the game trains, e.g. "Reaction", "Timing".
    let skills: [String]
    let scorePresentation: ScorePresentation

    init(
        id: String,
        name: String,
        subtitle: String,
        instructions: String,
        iconName: String,
        difficulty: GameDifficulty,
        skills: [String],
        scorePresentation: ScorePresentation = .points
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.instructions = instructions
        self.iconName = iconName
        self.difficulty = difficulty
        self.skills = skills
        self.scorePresentation = scorePresentation
    }
}
