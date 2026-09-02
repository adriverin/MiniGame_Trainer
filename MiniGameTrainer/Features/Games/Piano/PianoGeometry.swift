import CoreGraphics

/// Resolves the ratio-based layout of `PianoGameConfig` into points for a concrete scene size.
///
/// Simulation coordinates are "screen-down": origin at the top-left of the scene, y grows downward.
/// `PianoGameScene` converts to SpriteKit's bottom-left origin when positioning nodes.
struct PianoGeometry: Equatable {
    let sceneSize: CGSize
    let laneCount: Int
    let laneWidth: CGFloat
    let rowHeight: CGFloat
    let seam: CGFloat
    let tileSize: CGSize
    /// y of the playfield's top edge (tiles are clipped above it).
    let playfieldTop: CGFloat
    /// y of the miss line.
    let missLineY: CGFloat
    /// y below which rows are fully off-screen and can be recycled.
    let recycleY: CGFloat

    init(sceneSize: CGSize, config: PianoGameConfig) {
        self.sceneSize = sceneSize
        laneCount = max(1, config.laneCount)
        laneWidth = sceneSize.width / CGFloat(laneCount)
        rowHeight = sceneSize.height * config.rowHeightRatio
        seam = laneWidth * config.tileSeamRatio
        tileSize = CGSize(
            width: max(1, laneWidth * config.tileWidthRatio - seam),
            height: max(1, rowHeight - seam)
        )
        playfieldTop = sceneSize.height * config.playfieldTopRatio
        missLineY = sceneSize.height * config.missLineRatio
        recycleY = sceneSize.height + rowHeight
    }

    var playfieldHeight: CGFloat {
        sceneSize.height - playfieldTop
    }

    /// Distance a tile travels from becoming visible to reaching the miss line.
    var reactionDistance: CGFloat {
        max(1, missLineY - playfieldTop)
    }

    func laneCenterX(_ lane: Int) -> CGFloat {
        laneWidth * CGFloat(lane) + laneWidth / 2
    }

    func lane(forX x: CGFloat) -> Int? {
        guard x >= 0, x < sceneSize.width else { return nil }
        return min(laneCount - 1, Int(x / laneWidth))
    }

    /// Visible rectangle of a tile whose row top is at `rowTop` (screen-down coordinates).
    func tileFrame(lane: Int, rowTop: CGFloat) -> CGRect {
        CGRect(
            x: laneCenterX(lane) - tileSize.width / 2,
            y: rowTop + seam / 2,
            width: tileSize.width,
            height: tileSize.height
        )
    }

    /// Convert a screen-down point to SpriteKit scene coordinates (origin bottom-left).
    func toScene(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: sceneSize.height - point.y)
    }

    func fromScene(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: sceneSize.height - point.y)
    }
}
