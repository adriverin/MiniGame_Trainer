import CoreGraphics
import Foundation

struct SwipeFastGestureClassifier: Equatable {
    var minimumDistance: CGFloat
    var maximumDuration: TimeInterval

    init(minimumDistance: CGFloat, maximumDuration: TimeInterval) {
        self.minimumDistance = max(0, minimumDistance)
        self.maximumDuration = max(0, maximumDuration)
    }

    /// Inclusive distance threshold. SpriteKit Y-up: positive `dy` is `.up`.
    /// Horizontal wins only when `abs(dx) > abs(dy)`; a 45° tie is vertical.
    func classify(dx: CGFloat, dy: CGFloat, duration: TimeInterval) -> SwipeDirection? {
        guard duration <= maximumDuration else { return nil }
        let distance = hypot(dx, dy)
        guard distance >= minimumDistance else { return nil }
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        }
        return dy > 0 ? .up : .down
    }

    func classify(from start: CGPoint, to end: CGPoint, duration: TimeInterval) -> SwipeDirection? {
        classify(dx: end.x - start.x, dy: end.y - start.y, duration: duration)
    }
}
