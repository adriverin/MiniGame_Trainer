import SwiftUI
import UIKit

/// Central colour/typography definitions. UIKit colours are exposed for SpriteKit scenes.
enum AppTheme {
    enum UIColors {
        /// Very dark purple measured from the reference recording: RGB(26, 12, 51).
        static let gameBackground = UIColor(red: 26 / 255, green: 12 / 255, blue: 51 / 255, alpha: 1)
        /// Near-white tile fill measured from the reference: RGB(237, 237, 242).
        static let activeTile = UIColor(red: 237 / 255, green: 237 / 255, blue: 242 / 255, alpha: 1)
        static let scoreText = UIColor.white
        static let scoreShadow = UIColor(white: 0, alpha: 0.55)
        /// Red tint flashed over the whole scene on game over.
        static let failureFlash = UIColor(red: 0.75, green: 0.0, blue: 0.12, alpha: 1)
        static let hintText = UIColor(white: 1, alpha: 0.92)
        static let debugText = UIColor(red: 0.5, green: 1, blue: 0.6, alpha: 1)
        static let debugHitbox = UIColor(red: 0, green: 1, blue: 0.4, alpha: 0.6)
        static let debugMissLine = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.8)
    }

    enum Colors {
        static let background = Color(uiColor: UIColors.gameBackground)
        static let surface = Color(red: 0.16, green: 0.10, blue: 0.30)
        static let surfaceElevated = Color(red: 0.22, green: 0.15, blue: 0.38)
        static let accent = Color(red: 0.48, green: 0.62, blue: 1.0)
        static let success = Color(red: 0.35, green: 0.85, blue: 0.55)
        static let warning = Color(red: 1.0, green: 0.75, blue: 0.3)
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.65)
        static let divider = Color.white.opacity(0.12)
    }

    enum Metrics {
        static let cornerRadius: CGFloat = 20
        static let cardPadding: CGFloat = 18
        static let screenPadding: CGFloat = 20
    }

    enum Fonts {
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }

        static let title = Font.system(.largeTitle, design: .rounded).weight(.heavy)
        static let heading = Font.system(.title2, design: .rounded).weight(.bold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
        static let button = Font.system(.headline, design: .rounded).weight(.bold)
    }
}
