import Foundation

enum GameDifficulty: String, Codable, CaseIterable {
    case easy
    case medium
    case hard

    var displayName: String {
        rawValue.capitalized
    }
}
