import CoreGraphics
import Foundation

/// Pure gameplay model of one tile. Rendering lives in `PianoTileNode`.
struct PianoTile: Identifiable, Equatable {
    enum State: Equatable {
        case active
        case hit
        case missed
    }

    let id: UUID
    let lane: Int
    let rowIndex: Int
    var state: State = .active
    /// Game time at which the tile became visible inside the playfield.
    var visibleTime: TimeInterval?
    var hitTime: TimeInterval?
    /// 0 = tapped the moment it appeared, 1 = tapped right at the miss line.
    var tapDepth: CGFloat?

    init(id: UUID = UUID(), lane: Int, rowIndex: Int) {
        self.id = id
        self.lane = lane
        self.rowIndex = rowIndex
    }

    var reactionTime: TimeInterval? {
        guard let visibleTime, let hitTime else { return nil }
        return max(0, hitTime - visibleTime)
    }
}

/// A horizontal band of the scrolling column. Rows are contiguous; a row holds one or two tiles.
struct PianoRow: Identifiable, Equatable {
    let id: Int
    /// Lane used by the "no repeat" rule for the following row.
    let primaryLane: Int
    /// Top edge in screen-down coordinates.
    var top: CGFloat
    var tiles: [PianoTile]

    func bottom(rowHeight: CGFloat) -> CGFloat {
        top + rowHeight
    }

    var hasActiveTiles: Bool {
        tiles.contains { $0.state == .active }
    }

    func tile(inLane lane: Int) -> PianoTile? {
        tiles.first { $0.lane == lane }
    }
}
