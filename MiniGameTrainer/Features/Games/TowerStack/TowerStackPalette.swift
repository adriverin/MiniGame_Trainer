import UIKit

/// Colours of one rendered block. Purely cosmetic: never read by the game logic.
struct TowerStackBlockColors: Equatable {
    let top: UIColor
    let leftFace: UIColor
    let rightFace: UIColor
}

/// Procedural hue cycle measured from the reference (≈ 5° per block, constant S/V).
enum TowerStackPalette {
    static func colors(forBlockIndex index: Int, config: TowerStackGameConfig) -> TowerStackBlockColors {
        let degrees = config.initialHueDegrees + config.hueStepDegrees * CGFloat(index)
        let hue = (degrees / 360).truncatingRemainder(dividingBy: 1)
        let normalizedHue = hue < 0 ? hue + 1 : hue
        return TowerStackBlockColors(
            top: UIColor(hue: normalizedHue, saturation: config.saturation, brightness: config.brightness, alpha: 1),
            leftFace: UIColor(hue: normalizedHue, saturation: min(1, config.saturation * 0.93), brightness: config.brightness * config.leftFaceShade, alpha: 1),
            rightFace: UIColor(hue: normalizedHue, saturation: min(1, config.saturation * 0.97), brightness: config.brightness * config.rightFaceShade, alpha: 1)
        )
    }

    static let pedestal = TowerStackBlockColors(
        top: UIColor(white: 0.20, alpha: 1),
        leftFace: UIColor(white: 0.13, alpha: 1),
        rightFace: UIColor(white: 0.21, alpha: 1)
    )

    /// Background gradient from top to bottom (dark grey-purple → violet), measured from the reference.
    static let backgroundStops: [(location: CGFloat, color: UIColor)] = [
        (0.0, UIColor(red: 37 / 255, green: 36 / 255, blue: 44 / 255, alpha: 1)),
        (0.31, UIColor(red: 58 / 255, green: 49 / 255, blue: 96 / 255, alpha: 1)),
        (0.70, UIColor(red: 89 / 255, green: 65 / 255, blue: 181 / 255, alpha: 1)),
        (1.0, UIColor(red: 75 / 255, green: 54 / 255, blue: 158 / 255, alpha: 1)),
    ]
}
