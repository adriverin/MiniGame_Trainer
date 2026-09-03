import CoreGraphics
import Foundation
import UIKit

/// Original high-separation trainer palette. Families match the reference
/// (teal / cyan / blue / purple / orange / coral) without copying Playus RGB.
enum ColorReflexSwatch: String, CaseIterable, Equatable, Codable {
    case teal
    case cyan
    case blue
    case purple
    case orange
    case coral

    var red: CGFloat {
        switch self {
        case .teal: 0.08
        case .cyan: 0.20
        case .blue: 0.16
        case .purple: 0.48
        case .orange: 1.00
        case .coral: 0.98
        }
    }

    var green: CGFloat {
        switch self {
        case .teal: 0.74
        case .cyan: 0.78
        case .blue: 0.40
        case .purple: 0.20
        case .orange: 0.58
        case .coral: 0.38
        }
    }

    var blue: CGFloat {
        switch self {
        case .teal: 0.68
        case .cyan: 0.94
        case .blue: 0.98
        case .purple: 0.90
        case .orange: 0.10
        case .coral: 0.30
        }
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

enum ColorReflexBarStage: String, Equatable {
    case green
    case orange
    case red
}

struct ColorReflexPalette: Equatable {
    let swatches: [ColorReflexSwatch]

    init(swatches: [ColorReflexSwatch] = ColorReflexSwatch.allCases) {
        self.swatches = swatches.isEmpty ? ColorReflexSwatch.allCases : swatches
    }

    func color(after current: ColorReflexSwatch?, rng: inout AnyRandomNumberGenerator) -> ColorReflexSwatch {
        guard swatches.count > 1, let current, swatches.contains(current) else {
            return swatches.randomElement(using: &rng) ?? .teal
        }
        let others = swatches.filter { $0 != current }
        return others.randomElement(using: &rng) ?? current
    }
}
