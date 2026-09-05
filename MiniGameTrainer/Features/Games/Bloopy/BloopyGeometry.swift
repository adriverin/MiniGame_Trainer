import CoreGraphics
import Foundation

struct BloopyGeometry: Equatable {
    let sceneSize: CGSize
    let ballRadius: CGFloat
    let platformHeight: CGFloat
    let cameraFollowY: CGFloat
    let failureMargin: CGFloat
    let scoreUnit: CGFloat
    let recycleDistance: CGFloat
    let platformHorizontalMargin: CGFloat

    init(sceneSize: CGSize, config: BloopyGameConfig) {
        self.sceneSize = sceneSize
        ballRadius = max(5, sceneSize.width * config.ballDiameterRatio / 2)
        platformHeight = max(6, sceneSize.height * config.platformHeightRatio)
        cameraFollowY = sceneSize.height * config.cameraFollowYRatio
        failureMargin = sceneSize.height * config.failureMarginHeightRatio
        scoreUnit = max(1, sceneSize.height * config.scoreUnitHeightRatio)
        recycleDistance = sceneSize.height * config.recycleBelowHeightRatio
        platformHorizontalMargin = sceneSize.width * config.platformHorizontalMarginRatio
    }

    var width: CGFloat { sceneSize.width }
    var height: CGFloat { sceneSize.height }

    func screenY(worldY: CGFloat, cameraY: CGFloat) -> CGFloat {
        worldY - cameraY
    }

    func worldY(screenY: CGFloat, cameraY: CGFloat) -> CGFloat {
        screenY + cameraY
    }

    func platformTop(worldY: CGFloat) -> CGFloat {
        worldY + platformHeight / 2
    }

    func platformBottom(worldY: CGFloat) -> CGFloat {
        worldY - platformHeight / 2
    }

    var ballMinX: CGFloat { ballRadius }
    var ballMaxX: CGFloat { width - ballRadius }

    func playablePlatformMinX(width platformWidth: CGFloat) -> CGFloat {
        platformWidth / 2 + platformHorizontalMargin
    }

    func playablePlatformMaxX(width platformWidth: CGFloat) -> CGFloat {
        width - platformWidth / 2 - platformHorizontalMargin
    }
}
