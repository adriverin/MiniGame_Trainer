import CoreGraphics

struct JumpyProjectedPoint: Equatable {
    let point: CGPoint
    let depthScale: CGFloat
    let horizontalScale: CGFloat
    let rowPitch: CGFloat
}

struct JumpyWorldProjection: Equatable {
    let size: CGSize
    let config: JumpyGameConfig
    let cameraProgress: CGFloat

    func project(_ world: CGPoint) -> JumpyProjectedPoint {
        let distance = world.y - cameraProgress
        let depthScale = scale(atDistance: distance)
        let horizontalScale = 1 + (depthScale - 1) * config.horizontalDepthInfluence
        let pitch = size.height * config.rowHeightRatio
        let yOffset: CGFloat
        if abs(config.projectionDepthFalloff) < 1e-9 {
            yOffset = distance * pitch
        } else {
            yOffset = pitch * (1 - exp(-config.projectionDepthFalloff * distance)) / config.projectionDepthFalloff
        }
        return JumpyProjectedPoint(
            point: CGPoint(
                x: size.width / 2 + (world.x - 0.5) * size.width * horizontalScale,
                y: size.height * config.cameraAnchorYRatio + yOffset
            ),
            depthScale: depthScale,
            horizontalScale: horizontalScale,
            rowPitch: pitch * depthScale
        )
    }

    func worldRow(atScreenY screenY: CGFloat) -> CGFloat {
        let pitch = size.height * config.rowHeightRatio
        let offset = screenY - size.height * config.cameraAnchorYRatio
        guard abs(config.projectionDepthFalloff) >= 1e-9 else {
            return cameraProgress + offset / pitch
        }
        let argument = max(0.001, 1 - offset * config.projectionDepthFalloff / pitch)
        return cameraProgress - log(argument) / config.projectionDepthFalloff
    }

    var minimumVisibleWorldRow: CGFloat { worldRow(atScreenY: 0) }
    var maximumVisibleWorldRow: CGFloat { worldRow(atScreenY: size.height) }

    private func scale(atDistance distance: CGFloat) -> CGFloat {
        min(
            config.maximumDepthScale,
            max(config.minimumDepthScale, exp(-config.projectionDepthFalloff * distance))
        )
    }
}
