import CoreGraphics

struct DirectionsGeometry: Equatable {
    let sceneSize: CGSize
    let config: DirectionsGameConfig

    var scorePosition: CGPoint {
        CGPoint(x: sceneSize.width * config.scoreXRatio, y: sceneSize.height * config.scoreYRatio)
    }

    var levelPosition: CGPoint {
        CGPoint(x: sceneSize.width * config.levelXRatio, y: sceneSize.height * config.levelYRatio)
    }

    var phasePosition: CGPoint {
        CGPoint(x: sceneSize.width * config.phaseXRatio, y: sceneSize.height * config.phaseYRatio)
    }

    var sequenceRowOrigin: CGPoint {
        CGPoint(x: sceneSize.width * config.phaseXRatio, y: sceneSize.height * config.sequenceRowYRatio)
    }

    var sequenceIconSize: CGFloat { sceneSize.width * config.sequenceIconWidthRatio }
    var sequenceIconSpacing: CGFloat { sceneSize.width * config.sequenceIconSpacingRatio }

    var observeArrowCenter: CGPoint {
        CGPoint(
            x: sceneSize.width * config.observeArrowCenterXRatio,
            y: sceneSize.height * config.observeArrowCenterYRatio
        )
    }

    var observeArrowSize: CGSize {
        CGSize(
            width: sceneSize.width * config.observeArrowWidthRatio,
            height: sceneSize.height * config.observeArrowHeightRatio
        )
    }

    var dpadCenter: CGPoint {
        CGPoint(
            x: sceneSize.width * config.dpadCenterXRatio,
            y: sceneSize.height * config.dpadCenterYRatio
        )
    }

    var buttonSize: CGFloat { sceneSize.width * config.buttonSizeRatio }
    var buttonGap: CGFloat { sceneSize.width * config.buttonGapRatio }
    var buttonCornerRadius: CGFloat { buttonSize * config.buttonCornerRadiusRatio }
    var buttonArrowSize: CGFloat { buttonSize * config.buttonArrowSizeRatio }
    var buttonHitSize: CGFloat { buttonSize * config.buttonHitPaddingRatio }
    var buttonStep: CGFloat { buttonSize + buttonGap }

    func buttonCenter(for direction: Direction) -> CGPoint {
        switch direction {
        case .up: CGPoint(x: dpadCenter.x, y: dpadCenter.y + buttonStep)
        case .down: CGPoint(x: dpadCenter.x, y: dpadCenter.y - buttonStep)
        case .left: CGPoint(x: dpadCenter.x - buttonStep, y: dpadCenter.y)
        case .right: CGPoint(x: dpadCenter.x + buttonStep, y: dpadCenter.y)
        }
    }

    func buttonRect(for direction: Direction) -> CGRect {
        let center = buttonCenter(for: direction)
        return CGRect(
            x: center.x - buttonSize / 2,
            y: center.y - buttonSize / 2,
            width: buttonSize,
            height: buttonSize
        )
    }

    func hitRect(for direction: Direction) -> CGRect {
        let center = buttonCenter(for: direction)
        return CGRect(
            x: center.x - buttonHitSize / 2,
            y: center.y - buttonHitSize / 2,
            width: buttonHitSize,
            height: buttonHitSize
        )
    }

    func direction(at point: CGPoint) -> Direction? {
        Direction.allCases.first { hitRect(for: $0).contains(point) }
    }

    func sequenceIconCenter(at index: Int) -> CGPoint {
        let maxItems = max(1, config.sequenceRowMaxItems)
        let row = index / maxItems
        let column = index % maxItems
        let stride = sequenceIconSize + sequenceIconSpacing
        return CGPoint(
            x: sequenceRowOrigin.x + sequenceIconSize / 2 + CGFloat(column) * stride,
            y: sequenceRowOrigin.y - CGFloat(row) * stride
        )
    }
}
