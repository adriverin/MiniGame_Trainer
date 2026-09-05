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
        static let background = Color(red: 0.035, green: 0.065, blue: 0.12)
        static let surface = Color(red: 0.07, green: 0.115, blue: 0.18)
        static let surfaceElevated = Color(red: 0.10, green: 0.16, blue: 0.23)
        static let accent = Color(red: 0.20, green: 0.88, blue: 0.90)
        static let success = Color(red: 0.35, green: 0.85, blue: 0.55)
        static let warning = Color(red: 1.0, green: 0.75, blue: 0.3)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.67, green: 0.74, blue: 0.82)
        static let destructive = Color(red: 1.0, green: 0.40, blue: 0.43)
        static let divider = Color.white.opacity(0.12)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
    }

    enum Metrics {
        static let cornerRadius = Radius.large
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 20
        static let controlHeight: CGFloat = 52
        static let contentWidth: CGFloat = 600
        static let previewHeight: CGFloat = 180
    }

    enum Fonts {
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .rounded)
        }

        static let title = Font.system(.largeTitle, design: .rounded).weight(.heavy)
        static let heading = Font.system(.title2, design: .rounded).weight(.bold)
        static let cardTitle = Font.system(.title3, design: .rounded).weight(.bold)
        static let secondary = Font.system(.subheadline, design: .rounded)
        static let numeric = Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit()
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
        static let button = Font.system(.headline, design: .rounded).weight(.bold)
    }
}
