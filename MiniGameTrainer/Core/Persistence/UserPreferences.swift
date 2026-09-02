import Foundation
import Combine

/// Global user-facing settings persisted in UserDefaults.
@MainActor
final class UserPreferences: ObservableObject {
    @Published var soundEnabled: Bool {
        didSet { userDefaults.set(soundEnabled, forKey: Keys.sound) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { userDefaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    private let userDefaults: UserDefaults

    private enum Keys {
        static let sound = "preferences.soundEnabled"
        static let haptics = "preferences.hapticsEnabled"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        soundEnabled = userDefaults.object(forKey: Keys.sound) as? Bool ?? true
        hapticsEnabled = userDefaults.object(forKey: Keys.haptics) as? Bool ?? true
    }
}
