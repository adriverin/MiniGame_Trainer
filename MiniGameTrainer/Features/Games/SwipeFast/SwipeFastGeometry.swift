import CoreGraphics

struct SwipeFastGeometry: Equatable {
    let sceneSize: CGSize
    let config: SwipeFastGameConfig
    let boxSize: CGFloat
    let boxGap: CGFloat
    let cornerRadius: CGFloat
    let gridCenter: CGPoint
    let scorePosition: CGPoint
    let scoreFontSize: CGFloat
    let arrowSize: CGFloat
    let frames: [CGRect]

    init(sceneSize: CGSize, config: SwipeFastGameConfig) {
        self.sceneSize = sceneSize
        self.config = config
        boxSize = max(48, sceneSize.width * config.boxSizeRatio)
        boxGap = max(4, sceneSize.width * config.boxGapRatio)
        cornerRadius = boxSize * config.boxCornerRadiusRatio
        gridCenter = CGPoint(
            x: sceneSize.width * config.boxGridCenterXRatio,
            y: sceneSize.height * config.boxGridCenterYRatio
        )
        scorePosition = CGPoint(
            x: sceneSize.width * config.scoreXRatio,
            y: sceneSize.height * config.scoreYRatio
        )
        scoreFontSize = max(28, sceneSize.width * config.scoreFontRatio)
        arrowSize = boxSize * config.arrowSizeRatio
        let step = boxSize + boxGap
        let origins = [
            CGPoint(x: gridCenter.x - step / 2, y: gridCenter.y + step / 2),
            CGPoint(x: gridCenter.x + step / 2, y: gridCenter.y + step / 2),
            CGPoint(x: gridCenter.x - step / 2, y: gridCenter.y - step / 2),
            CGPoint(x: gridCenter.x + step / 2, y: gridCenter.y - step / 2),
        ]
        let resolvedSize = boxSize
        frames = origins.map { center in
            CGRect(x: center.x - resolvedSize / 2, y: center.y - resolvedSize / 2, width: resolvedSize, height: resolvedSize)
        }
    }

    var minimumSwipeDistance: CGFloat { boxSize * config.minimumSwipeDistanceRatio }

    func frame(for box: SwipeFastBoxIndex) -> CGRect {
        frames[box.rawValue]
    }

    func box(containing point: CGPoint) -> SwipeFastBoxIndex? {
        SwipeFastBoxIndex.allCases.first { frame(for: $0).contains(point) }
    }

    func barFrame(for box: SwipeFastBoxIndex, remainingFraction: Double) -> CGRect {
        let boxFrame = frame(for: box)
        let inset = boxSize * config.barHorizontalInsetRatio
        let height = max(3, boxSize * config.barHeightRatio)
        let bottom = boxSize * config.barBottomInsetRatio
        let fullWidth = max(0, boxFrame.width - inset * 2)
        let width = fullWidth * CGFloat(min(max(remainingFraction, 0), 1))
        return CGRect(
            x: boxFrame.minX + inset,
            y: boxFrame.minY + bottom,
            width: width,
            height: height
        )
    }

    func fullBarTrackFrame(for box: SwipeFastBoxIndex) -> CGRect {
        barFrame(for: box, remainingFraction: 1)
    }

    func arrowCenter(for box: SwipeFastBoxIndex) -> CGPoint {
        let frame = frame(for: box)
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}
