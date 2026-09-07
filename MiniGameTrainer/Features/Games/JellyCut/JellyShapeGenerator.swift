import CoreGraphics
import Foundation

struct SeededJellyRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

enum JellyShapeGenerator {
    static func sessionShapes<R: RandomNumberGenerator>(
        pointCount: Int = 18,
        using random: inout R
    ) -> [[CGPoint]] {
        (0..<3).map { _ in generate(pointCount: pointCount, using: &random) }
    }

    static func generate<R: RandomNumberGenerator>(
        pointCount requestedCount: Int = 18,
        using random: inout R
    ) -> [CGPoint] {
        let count = min(max(requestedCount, 12), 20)
        for _ in 0..<40 {
            let phase2 = unit(&random) * 2 * .pi
            let phase3 = unit(&random) * 2 * .pi
            let phase5 = unit(&random) * 2 * .pi
            let amplitude2 = 0.075 + unit(&random) * 0.055
            let amplitude3 = 0.070 + unit(&random) * 0.060
            let amplitude5 = 0.022 + unit(&random) * 0.028
            let xAspect = 0.91 + unit(&random) * 0.18
            let yAspect = 0.91 + unit(&random) * 0.18
            var points: [CGPoint] = []
            points.reserveCapacity(count)
            for index in 0..<count {
                let baseAngle = 2 * Double.pi * Double(index) / Double(count)
                let angularJitter = (unit(&random) - 0.5) * (0.30 / Double(count)) * 2 * .pi
                let angle = baseAngle + angularJitter
                let localNoise = (unit(&random) - 0.5) * 0.035
                let radius = 1
                    + amplitude2 * sin(2 * angle + phase2)
                    + amplitude3 * cos(3 * angle + phase3)
                    + amplitude5 * sin(5 * angle + phase5)
                    + localNoise
                points.append(CGPoint(
                    x: cos(angle) * radius * xAspect,
                    y: sin(angle) * radius * yAspect
                ))
            }
            let normalized = normalize(points)
            let denseBoundary = smoothClosed(normalized, samplesPerSegment: 4)
            if validate(denseBoundary) { return denseBoundary }
        }
        return smoothClosed(fallback(pointCount: count), samplesPerSegment: 4)
    }

    static func validate(_ polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 12,
              JellyPolygonGeometry.isSimple(polygon),
              JellyPolygonGeometry.area(of: polygon) > 0.55,
              JellyPolygonGeometry.minimumEdgeLength(of: polygon) > 0.005 else { return false }
        return polygon.allSatisfy {
            abs($0.x) <= 0.56 && abs($0.y) <= 0.56 && $0.x.isFinite && $0.y.isFinite
        }
    }

    private static func normalize(_ polygon: [CGPoint]) -> [CGPoint] {
        guard let minX = polygon.map(\.x).min(), let maxX = polygon.map(\.x).max(),
              let minY = polygon.map(\.y).min(), let maxY = polygon.map(\.y).max() else { return [] }
        let width = max(maxX - minX, 0.001)
        let height = max(maxY - minY, 0.001)
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let scale = min(1 / width, 1 / height)
        return polygon.map {
            CGPoint(x: ($0.x - center.x) * scale, y: ($0.y - center.y) * scale)
        }
    }

    private static func fallback(pointCount: Int) -> [CGPoint] {
        (0..<pointCount).map { index in
            let angle = 2 * Double.pi * Double(index) / Double(pointCount)
            let radius = 0.46 + 0.045 * sin(3 * angle + 0.4) + 0.025 * cos(2 * angle)
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    /// Catmull-Rom interpolation creates a soft visual boundary. The returned dense polygon is
    /// also the scoring polygon, keeping presentation and area measurement on one source of truth.
    private static func smoothClosed(_ controls: [CGPoint], samplesPerSegment: Int) -> [CGPoint] {
        guard controls.count >= 4 else { return controls }
        let samples = max(1, samplesPerSegment)
        var result: [CGPoint] = []
        result.reserveCapacity(controls.count * samples)
        for index in controls.indices {
            let p0 = controls[(index - 1 + controls.count) % controls.count]
            let p1 = controls[index]
            let p2 = controls[(index + 1) % controls.count]
            let p3 = controls[(index + 2) % controls.count]
            for sample in 0..<samples {
                let t = CGFloat(sample) / CGFloat(samples)
                let t2 = t * t
                let t3 = t2 * t
                result.append(CGPoint(
                    x: 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t
                        + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2
                        + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3),
                    y: 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t
                        + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2
                        + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
                ))
            }
        }
        return result
    }

    private static func unit<R: RandomNumberGenerator>(_ random: inout R) -> Double {
        Double(random.next() >> 11) / Double(1 << 53)
    }
}
