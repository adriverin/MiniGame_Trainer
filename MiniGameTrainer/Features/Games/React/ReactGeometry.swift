import CoreGraphics

struct ReactGeometry: Equatable {
    let sceneSize: CGSize
    let config: ReactGameConfig

    var circleDiameter: CGFloat { sceneSize.width * config.circleDiameterRatio }
    var horizontalGap: CGFloat { circleDiameter * config.horizontalGapToDiameterRatio }
    var verticalGap: CGFloat { circleDiameter * config.verticalGapToDiameterRatio }
    var horizontalStep: CGFloat { circleDiameter + horizontalGap }
    var verticalStep: CGFloat { circleDiameter + verticalGap }
    var gridCenter: CGPoint {
        CGPoint(
            x: sceneSize.width * config.gridCenterXRatio,
            y: sceneSize.height * config.gridCenterYRatio
        )
    }
    var gridWidth: CGFloat { circleDiameter * 3 + horizontalGap * 2 }
    var gridHeight: CGFloat { circleDiameter * 3 + verticalGap * 2 }

    func center(for index: Int) -> CGPoint {
        precondition((0..<9).contains(index))
        let row = index / 3
        let column = index % 3
        return CGPoint(
            x: gridCenter.x + CGFloat(column - 1) * horizontalStep,
            y: gridCenter.y + CGFloat(1 - row) * verticalStep
        )
    }

    func targetIndex(at point: CGPoint) -> Int? {
        let radiusSquared = circleDiameter * circleDiameter / 4
        return (0..<9).first { index in
            let target = center(for: index)
            let dx = point.x - target.x
            let dy = point.y - target.y
            return dx * dx + dy * dy <= radiusSquared
        }
    }
}
