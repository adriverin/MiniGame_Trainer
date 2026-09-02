import SpriteKit

/// Visual counterpart of a `PianoTile`. Reused for the tile's whole life; no per-frame allocation.
final class PianoTileNode: SKSpriteNode {
    private(set) var tileID: UUID
    private(set) var renderedState: PianoTile.State = .active

    init(tile: PianoTile, size: CGSize) {
        tileID = tile.id
        super.init(texture: nil, color: AppTheme.UIColors.activeTile, size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        zPosition = 10
        name = "tile"
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not supported")
    }

    /// Reproduces the reference: an instant drop to a faint ghost that then settles even fainter.
    func applyHit(config: PianoGameConfig) {
        guard renderedState != .hit else { return }
        renderedState = .hit
        removeAllActions()
        alpha = config.hitTileInitialOpacity
        let settle = SKAction.fadeAlpha(to: config.hitTileRestingOpacity, duration: config.hitTileFadeDuration)
        settle.timingMode = .easeOut
        run(settle)
    }

    func applyMissed() {
        guard renderedState != .missed else { return }
        renderedState = .missed
        removeAllActions()
        alpha = 1
    }

    func resetToActive() {
        renderedState = .active
        removeAllActions()
        alpha = 1
        color = AppTheme.UIColors.activeTile
    }

    /// Pooled nodes are reused for new tiles.
    func rebind(to id: UUID) {
        tileID = id
    }
}
