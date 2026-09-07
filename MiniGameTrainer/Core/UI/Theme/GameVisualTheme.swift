import SwiftUI

/// Lightweight shell-only identity for a game. Gameplay owns its own palette and rendering.
struct GameVisualTheme {
    let id: String
    let primary: Color
    let secondary: Color
    let motif: GameMotif

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum GameMotif: String, CaseIterable {
    case keys
    case bounce
    case burst
    case stack
    case target
    case orbit
    case timer
    case grid
    case path
    case arrows
    case swipe
    case speed
    case climb
    case color
    case jump
    case zig
    case lanes
    case split
}

struct GameInstruction: Identifiable, Hashable {
    let title: String
    let detail: String
    let systemImage: String

    var id: String { title }
}

struct GamePresentation {
    let primaryRule: String
    let instructions: [GameInstruction]
}

/// One central mapping gives every registered game a restrained visual identity and concise copy.
enum GamePresentationCatalog {
    static let starterGameID = "piano"

    private static let themes: [String: GameVisualTheme] = [
        "piano": .init(id: "piano", primary: Color(hex: 0x42D9FF), secondary: Color(hex: 0x3578F6), motif: .keys),
        "trampbox": .init(id: "trampbox", primary: Color(hex: 0xF254C2), secondary: Color(hex: 0x9747FF), motif: .bounce),
        "react": .init(id: "react", primary: Color(hex: 0xFFB33F), secondary: Color(hex: 0xFF694D), motif: .burst),
        "towerStack": .init(id: "towerStack", primary: Color(hex: 0xA980FF), secondary: Color(hex: 0x665CFF), motif: .stack),
        "centerHit": .init(id: "centerHit", primary: Color(hex: 0x5DE2A5), secondary: Color(hex: 0x20BFC9), motif: .target),
        "keepUp": .init(id: "keepUp", primary: Color(hex: 0x6BE6CB), secondary: Color(hex: 0x3C8DFF), motif: .orbit),
        "timesUp": .init(id: "timesUp", primary: Color(hex: 0xFFD166), secondary: Color(hex: 0xF28C4B), motif: .timer),
        "grid": .init(id: "grid", primary: Color(hex: 0x78A8FF), secondary: Color(hex: 0x7258E8), motif: .grid),
        "trace": .init(id: "trace", primary: Color(hex: 0x67E4F2), secondary: Color(hex: 0x6D70FF), motif: .path),
        "directions": .init(id: "directions", primary: Color(hex: 0x72E38E), secondary: Color(hex: 0x2FA7B8), motif: .arrows),
        "tapSeven": .init(id: "tapSeven", primary: Color(hex: 0xFFC857), secondary: Color(hex: 0xEF6A5B), motif: .timer),
        "swipeFast": .init(id: "swipeFast", primary: Color(hex: 0xFF6B9D), secondary: Color(hex: 0x826BFF), motif: .swipe),
        "targetSpeed": .init(id: "targetSpeed", primary: Color(hex: 0xFF6178), secondary: Color(hex: 0xE33D9F), motif: .speed),
        "bloopy": .init(id: "bloopy", primary: Color(hex: 0x5CE1E6), secondary: Color(hex: 0x7B68EE), motif: .climb),
        "colorReflex": .init(id: "colorReflex", primary: Color(hex: 0xFF6F61), secondary: Color(hex: 0x25C7B7), motif: .color),
        "jumpy": .init(id: "jumpy", primary: Color(hex: 0xFFD84D), secondary: Color(hex: 0x47BE7D), motif: .jump),
        "zig": .init(id: "zig", primary: Color(hex: 0xF463D8), secondary: Color(hex: 0x795BFF), motif: .zig),
        "laneRush": .init(id: "laneRush", primary: Color(hex: 0xFF6B55), secondary: Color(hex: 0xFFB238), motif: .lanes),
        "jellyCut": .init(id: "jellyCut", primary: Color(hex: 0x71E68B), secondary: Color(hex: 0xF46EB3), motif: .split),
    ]

    private static let presentations: [String: GamePresentation] = [
        "piano": .init(primaryRule: "Tap every white tile before it crosses the line.", instructions: [
            .init(title: "Follow the lanes", detail: "White tiles move down four lanes.", systemImage: "pianokeys"),
            .init(title: "Tap cleanly", detail: "A missed tile or empty-lane tap ends the run.", systemImage: "hand.tap.fill"),
            .init(title: "Build your score", detail: "Higher is better.", systemImage: "chart.line.uptrend.xyaxis"),
        ]),
        "trampbox": .init(primaryRule: "Guide the bouncing ball from platform to platform.", instructions: [
            .init(title: "Drag to steer", detail: "Move left and right while the ball bounces automatically.", systemImage: "arrow.left.and.right"),
            .init(title: "Land precisely", detail: "Platforms narrow as you progress.", systemImage: "rectangle.compress.vertical"),
            .init(title: "Keep climbing", detail: "Higher is better.", systemImage: "arrow.up"),
        ]),
        "react": .init(primaryRule: "Tap the circle the instant it lights up.", instructions: [
            .init(title: "Wait for the signal", detail: "Each target lights after a random delay.", systemImage: "eye.fill"),
            .init(title: "React fast", detail: "Tap as soon as the circle changes.", systemImage: "hand.tap.fill"),
            .init(title: "Beat your average", detail: "Lower milliseconds are better.", systemImage: "stopwatch.fill"),
        ]),
        "towerStack": .init(primaryRule: "Drop each moving block onto the tower.", instructions: [
            .init(title: "Tap to place", detail: "Only the overlapping part survives.", systemImage: "hand.tap.fill"),
            .init(title: "Stay centered", detail: "Misses make the tower narrower.", systemImage: "align.horizontal.center.fill"),
            .init(title: "Climb higher", detail: "Blocks speed up as you go.", systemImage: "square.stack.3d.up.fill"),
        ]),
        "centerHit": .init(primaryRule: "Tap when the moving line reaches the exact center.", instructions: [
            .init(title: "Watch the line", detail: "It moves back and forth across the bar.", systemImage: "eye.fill"),
            .init(title: "Hit the center", detail: "The line accelerates after every attempt.", systemImage: "scope"),
            .init(title: "Five attempts", detail: "Average precision is your score; higher is better.", systemImage: "percent"),
        ]),
        "keepUp": .init(primaryRule: "Keep the platform beneath the falling ball.", instructions: [
            .init(title: "Drag freely", detail: "Move the circular platform in any direction.", systemImage: "move.3d"),
            .init(title: "Read the bounce", detail: "Track where the ball will land next.", systemImage: "circle.bottomhalf.filled"),
            .init(title: "Do not miss", detail: "Each bounce scores; one miss ends the run.", systemImage: "exclamationmark.circle.fill"),
        ]),
        "timesUp": .init(primaryRule: "Tap when you think the hidden timer reaches zero.", instructions: [
            .init(title: "Watch the bar", detail: "It disappears halfway through each round.", systemImage: "hourglass"),
            .init(title: "Estimate the finish", detail: "Tap when the full time has elapsed.", systemImage: "hand.tap.fill"),
            .init(title: "Three rounds", detail: "Lower average timing error is better.", systemImage: "stopwatch.fill"),
        ]),
        "grid": .init(primaryRule: "Memorize the highlighted cells, then rebuild the pattern.", instructions: [
            .init(title: "Study the grid", detail: "Highlighted cells disappear after a short time.", systemImage: "eye.fill"),
            .init(title: "Recreate it", detail: "Select the cells you remember, then submit.", systemImage: "square.grid.3x3.fill"),
            .init(title: "Keep advancing", detail: "Patterns get harder; higher is better.", systemImage: "brain.head.profile"),
        ]),
        "trace": .init(primaryRule: "Memorize the path, then trace it back from memory.", instructions: [
            .init(title: "Watch the path", detail: "Remember the order of the connected dots.", systemImage: "eye.fill"),
            .init(title: "Trace from memory", detail: "Drag through the dots after the path disappears.", systemImage: "scribble.variable"),
            .init(title: "Go farther", detail: "Patterns grow harder; higher is better.", systemImage: "chart.line.uptrend.xyaxis"),
        ]),
        "directions": .init(primaryRule: "Watch the arrows, then repeat their sequence.", instructions: [
            .init(title: "Observe", detail: "Remember each arrow in order.", systemImage: "eye.fill"),
            .init(title: "Repeat", detail: "Use the direction buttons when it is your turn.", systemImage: "dpad.fill"),
            .init(title: "Extend the sequence", detail: "Longer recalls earn a higher score.", systemImage: "brain.head.profile"),
        ]),
        "tapSeven": .init(primaryRule: "Stop the timer as close as possible to exactly 7 seconds.", instructions: [
            .init(title: "Watch the timer", detail: "Track the elapsed time carefully.", systemImage: "timer"),
            .init(title: "Tap at seven", detail: "Stop it at exactly 7.00 seconds.", systemImage: "hand.tap.fill"),
            .init(title: "Minimize error", detail: "Lower timing error is better.", systemImage: "scope"),
        ]),
        "swipeFast": .init(primaryRule: "Swipe each box in the direction it shows.", instructions: [
            .init(title: "Track four boxes", detail: "Every box has its own arrow and timer.", systemImage: "square.grid.2x2.fill"),
            .init(title: "Swipe correctly", detail: "Match each arrow before its timer expires.", systemImage: "hand.draw.fill"),
            .init(title: "Keep them alive", detail: "The pace rises with your score.", systemImage: "bolt.fill"),
        ]),
        "targetSpeed": .init(primaryRule: "Tap each target before it disappears.", instructions: [
            .init(title: "Tap the targets", detail: "Clear each one before its timer runs out.", systemImage: "target"),
            .init(title: "It gets harder", detail: "Targets become smaller and more numerous.", systemImage: "arrow.up.right"),
            .init(title: "Three lives", detail: "Miss a target and lose one; higher is better.", systemImage: "heart.fill"),
        ]),
        "bloopy": .init(primaryRule: "Steer the bouncing ball up the platforms.", instructions: [
            .init(title: "Tap to steer", detail: "Use the left or right side while the ball auto-bounces.", systemImage: "arrow.left.and.right"),
            .init(title: "Find the next platform", detail: "Adjust in the air to land safely.", systemImage: "rectangle.fill"),
            .init(title: "Climb higher", detail: "Your height is your score.", systemImage: "arrow.up"),
        ]),
        "colorReflex": .init(primaryRule: "Wait for the color change, then tap immediately.", instructions: [
            .init(title: "Hold your tap", detail: "Wait until the background changes color.", systemImage: "eye.fill"),
            .init(title: "React quickly", detail: "Tap the moment the new color appears.", systemImage: "hand.tap.fill"),
            .init(title: "Avoid false starts", detail: "Early taps cost time; higher is better.", systemImage: "exclamationmark.circle.fill"),
        ]),
        "jumpy": .init(primaryRule: "Cross moving traffic and keep advancing.", instructions: [
            .init(title: "Tap to move forward", detail: "A tap always jumps one step ahead.", systemImage: "hand.tap.fill"),
            .init(title: "Swipe to reposition", detail: "Jump left, right, forward, or backward.", systemImage: "arrow.up.and.down.and.arrow.left.and.right"),
            .init(title: "Avoid traffic", detail: "One collision ends the run; distance is your score.", systemImage: "car.fill"),
        ]),
        "zig": .init(primaryRule: "Change direction at each bend and stay on the path.", instructions: [
            .init(title: "Tap to turn", detail: "Every tap switches the ball's direction.", systemImage: "hand.tap.fill"),
            .init(title: "Read the bends", detail: "Time each turn before the path changes.", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill"),
            .init(title: "Stay on course", detail: "Speed increases; distance is your score.", systemImage: "location.north.fill"),
        ]),
        "laneRush": .init(primaryRule: "Change lanes to dodge oncoming traffic.", instructions: [
            .init(title: "Move between lanes", detail: "Tap either side or swipe left and right.", systemImage: "arrow.left.and.right"),
            .init(title: "Read the traffic", detail: "Choose a clear lane before cars reach you.", systemImage: "car.2.fill"),
            .init(title: "Drive farther", detail: "One collision ends the run; distance is your score.", systemImage: "road.lanes"),
        ]),
        "jellyCut": .init(primaryRule: "Slice each jelly to match the requested fraction.", instructions: [
            .init(title: "Draw one straight cut", detail: "Swipe fully across the jelly.", systemImage: "scissors"),
            .init(title: "Match the fraction", detail: "Cut one half, one third, then one quarter.", systemImage: "circle.lefthalf.filled"),
            .init(title: "Three cuts", detail: "Average relative precision is your score; higher is better.", systemImage: "percent"),
        ]),
    ]

    static var mappedGameIDs: Set<String> { Set(themes.keys) }

    static func theme(for gameID: String) -> GameVisualTheme {
        themes[gameID] ?? .init(
            id: "fallback",
            primary: AppTheme.Colors.accent,
            secondary: Color(hex: 0x667A99),
            motif: .burst
        )
    }

    static func presentation(for descriptor: MiniGameDescriptor) -> GamePresentation {
        presentations[descriptor.id] ?? .init(
            primaryRule: descriptor.subtitle,
            instructions: [
                .init(title: "How to play", detail: descriptor.instructions, systemImage: descriptor.iconName),
                .init(
                    title: descriptor.scorePresentation.comparison == .lowerIsBetter ? "Aim lower" : "Aim higher",
                    detail: descriptor.scorePresentation.comparison == .lowerIsBetter ? "Lower is better." : "Higher is better.",
                    systemImage: "chart.line.uptrend.xyaxis"
                ),
            ]
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
