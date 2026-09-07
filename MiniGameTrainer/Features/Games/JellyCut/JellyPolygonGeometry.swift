import CoreGraphics
import Foundation

struct JellyCutLine: Equatable {
    let point: CGPoint
    let direction: CGVector

    init?(start: CGPoint, end: CGPoint, epsilon: Double = 1e-8) {
        let dx = Double(end.x - start.x)
        let dy = Double(end.y - start.y)
        let length = hypot(dx, dy)
        guard length > epsilon else { return nil }
        point = start
        direction = CGVector(dx: dx / length, dy: dy / length)
    }

    func signedSide(of value: CGPoint) -> Double {
        Double(direction.dx) * Double(value.y - point.y)
            - Double(direction.dy) * Double(value.x - point.x)
    }

    var normal: CGVector { CGVector(dx: -direction.dy, dy: direction.dx) }
}

struct JellyPolygonSplit: Equatable {
    let negative: [CGPoint]
    let positive: [CGPoint]
    let intersections: [CGPoint]
}

enum JellyPolygonGeometry {
    static func area(of polygon: [CGPoint]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        var twiceArea = 0.0
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            let point = polygon[index]
            twiceArea += Double(point.x * next.y - next.x * point.y)
        }
        return abs(twiceArea) * 0.5
    }

    static func signedArea(of polygon: [CGPoint]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        var twiceArea = 0.0
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            let point = polygon[index]
            twiceArea += Double(point.x * next.y - next.x * point.y)
        }
        return twiceArea * 0.5
    }

    static func centroid(of polygon: [CGPoint]) -> CGPoint {
        guard polygon.count >= 3 else { return .zero }
        var crossSum = 0.0
        var xSum = 0.0
        var ySum = 0.0
        for index in polygon.indices {
            let point = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            let cross = Double(point.x * next.y - next.x * point.y)
            crossSum += cross
            xSum += Double(point.x + next.x) * cross
            ySum += Double(point.y + next.y) * cross
        }
        guard abs(crossSum) > 1e-12 else {
            let count = CGFloat(polygon.count)
            return CGPoint(
                x: polygon.reduce(0) { $0 + $1.x } / count,
                y: polygon.reduce(0) { $0 + $1.y } / count
            )
        }
        return CGPoint(x: xSum / (3 * crossSum), y: ySum / (3 * crossSum))
    }

    /// Splits a simple polygon in one pass so the exact same intersection coordinates are
    /// inserted into both output boundaries.
    static func split(
        _ polygon: [CGPoint],
        by line: JellyCutLine,
        epsilon: Double = 1e-8
    ) -> JellyPolygonSplit? {
        guard polygon.count >= 3 else { return nil }
        var negative: [CGPoint] = []
        var positive: [CGPoint] = []
        var intersections: [CGPoint] = []

        for index in polygon.indices {
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            let currentSide = line.signedSide(of: current)
            let nextSide = line.signedSide(of: next)

            if currentSide <= epsilon { appendUnique(current, to: &negative, epsilon: epsilon) }
            if currentSide >= -epsilon { appendUnique(current, to: &positive, epsilon: epsilon) }

            if (currentSide < -epsilon && nextSide > epsilon)
                || (currentSide > epsilon && nextSide < -epsilon) {
                let ratio = currentSide / (currentSide - nextSide)
                let intersection = CGPoint(
                    x: current.x + CGFloat(ratio) * (next.x - current.x),
                    y: current.y + CGFloat(ratio) * (next.y - current.y)
                )
                appendUnique(intersection, to: &negative, epsilon: epsilon)
                appendUnique(intersection, to: &positive, epsilon: epsilon)
                appendDistinct(intersection, to: &intersections, epsilon: epsilon)
            } else if abs(currentSide) <= epsilon {
                appendDistinct(current, to: &intersections, epsilon: epsilon)
            }
        }

        negative = cleaned(negative, epsilon: epsilon)
        positive = cleaned(positive, epsilon: epsilon)
        intersections = distinct(intersections, epsilon: epsilon)
        guard negative.count >= 3, positive.count >= 3, intersections.count >= 2 else { return nil }
        return JellyPolygonSplit(
            negative: negative,
            positive: positive,
            intersections: intersections
        )
    }

    static func isSimple(_ polygon: [CGPoint], epsilon: Double = 1e-8) -> Bool {
        guard polygon.count >= 3 else { return false }
        for index in polygon.indices {
            let a1 = polygon[index]
            let a2 = polygon[(index + 1) % polygon.count]
            if distance(a1, a2) <= epsilon { return false }
            for other in polygon.indices where other > index {
                if other == index || other == (index + 1) % polygon.count
                    || index == (other + 1) % polygon.count { continue }
                let b1 = polygon[other]
                let b2 = polygon[(other + 1) % polygon.count]
                if segmentsIntersect(a1, a2, b1, b2, epsilon: epsilon) { return false }
            }
        }
        return true
    }

    static func minimumEdgeLength(of polygon: [CGPoint]) -> Double {
        guard !polygon.isEmpty else { return 0 }
        return polygon.indices.map {
            distance(polygon[$0], polygon[($0 + 1) % polygon.count])
        }.min() ?? 0
    }

    static func areaIsConserved(
        original: [CGPoint], split: JellyPolygonSplit, tolerance: Double = 1e-7
    ) -> Bool {
        let total = area(of: original)
        guard total > 0 else { return false }
        let pieces = area(of: split.negative) + area(of: split.positive)
        return abs(pieces - total) <= max(tolerance, total * tolerance)
    }

    private static func appendUnique(
        _ point: CGPoint, to values: inout [CGPoint], epsilon: Double
    ) {
        if let last = values.last, distance(last, point) <= epsilon { return }
        values.append(point)
    }

    private static func appendDistinct(
        _ point: CGPoint, to values: inout [CGPoint], epsilon: Double
    ) {
        guard !values.contains(where: { distance($0, point) <= epsilon }) else { return }
        values.append(point)
    }

    private static func distinct(_ values: [CGPoint], epsilon: Double) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in values { appendDistinct(point, to: &result, epsilon: epsilon) }
        return result
    }

    private static func cleaned(_ values: [CGPoint], epsilon: Double) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in values { appendUnique(point, to: &result, epsilon: epsilon) }
        if result.count > 1, distance(result[0], result[result.count - 1]) <= epsilon {
            result.removeLast()
        }
        return result
    }

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> Double {
        hypot(Double(lhs.x - rhs.x), Double(lhs.y - rhs.y))
    }

    private static func segmentsIntersect(
        _ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, epsilon: Double
    ) -> Bool {
        let o1 = orientation(a, b, c)
        let o2 = orientation(a, b, d)
        let o3 = orientation(c, d, a)
        let o4 = orientation(c, d, b)
        if ((o1 > epsilon && o2 < -epsilon) || (o1 < -epsilon && o2 > epsilon))
            && ((o3 > epsilon && o4 < -epsilon) || (o3 < -epsilon && o4 > epsilon)) {
            return true
        }
        if abs(o1) <= epsilon && onSegment(a, b, c, epsilon: epsilon) { return true }
        if abs(o2) <= epsilon && onSegment(a, b, d, epsilon: epsilon) { return true }
        if abs(o3) <= epsilon && onSegment(c, d, a, epsilon: epsilon) { return true }
        if abs(o4) <= epsilon && onSegment(c, d, b, epsilon: epsilon) { return true }
        return false
    }

    private static func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        Double(b.x - a.x) * Double(c.y - a.y) - Double(b.y - a.y) * Double(c.x - a.x)
    }

    private static func onSegment(
        _ a: CGPoint, _ b: CGPoint, _ point: CGPoint, epsilon: Double
    ) -> Bool {
        Double(point.x) >= Double(min(a.x, b.x)) - epsilon
            && Double(point.x) <= Double(max(a.x, b.x)) + epsilon
            && Double(point.y) >= Double(min(a.y, b.y)) - epsilon
            && Double(point.y) <= Double(max(a.y, b.y)) + epsilon
    }
}
