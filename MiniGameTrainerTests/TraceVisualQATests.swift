import UIKit
import XCTest
@testable import MiniGameTrainer

@MainActor
final class TraceVisualQATests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)
    private let outputDirectory = URL(fileURLWithPath: "/Users/adrianro/Desktop/finance-blockchain/MiniGame_Trainer-trace-qa")

    func testLineWidthStaysThinOnLongPaths() {
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: TraceHexField(radius: 3))
        XCTAssertLessThan(geometry.lineWidth, geometry.nodeVisualRadius)
        XCTAssertLessThan(geometry.nodeVisualRadius * 2, geometry.spacing * 0.35)
        var rng = AnyRandomNumberGenerator.seeded(2026)
        let generator = TracePatternGenerator(config: .reference)
        for edges in [3, 8, 14, 21] {
            let path = generator.generate(field: geometry.field, length: edges + 1, rng: &rng)
            XCTAssertEqual(path.count, edges + 1)
            var previous: CGPoint?
            for node in path {
                let point = geometry.position(for: node)
                if let previous {
                    let distance = hypot(point.x - previous.x, point.y - previous.y)
                    XCTAssertEqual(distance, geometry.spacing, accuracy: 1e-4, "gap or jump on \(edges)-edge path")
                }
                previous = point
            }
        }
    }

    func testWriteQAScreenshotsOutsideGit() throws {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try writeField(radius: 1, name: "radius-1-7-dots.png")
        try writeField(radius: 2, name: "radius-2-19-dots.png")
        try writeField(radius: 3, name: "radius-3-37-dots.png")
        try writePath(edges: 14, color: TraceGameConfig.reference.referenceColor, name: "yellow-long-target.png")
        try writePath(edges: 16, color: TraceGameConfig.reference.playerColor, name: "cyan-long-trace.png")
        try writePath(edges: 10, color: TraceGameConfig.reference.incorrectColor, name: "red-failure-trace.png")
        for name in [
            "radius-1-7-dots.png",
            "radius-2-19-dots.png",
            "radius-3-37-dots.png",
            "yellow-long-target.png",
            "cyan-long-trace.png",
            "red-failure-trace.png",
        ] {
            let url = outputDirectory.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), url.path)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertGreaterThan((attributes[.size] as? NSNumber)?.intValue ?? 0, 8_000)
        }
    }

    private func writeField(radius: Int, name: String) throws {
        let field = TraceHexField(radius: radius)
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: field)
        try render(name: name, geometry: geometry, path: [], pathColor: .clear, highlight: [])
    }

    private func writePath(edges: Int, color: UIColor, name: String) throws {
        let field = TraceHexField(radius: 3)
        let geometry = TraceGeometry(sceneSize: sceneSize, config: .reference, field: field)
        var rng = AnyRandomNumberGenerator.seeded(77)
        let path = TracePatternGenerator(config: .reference).generate(field: field, length: edges + 1, rng: &rng)
        try render(name: name, geometry: geometry, path: path, pathColor: color, highlight: path)
    }

    private func render(
        name: String,
        geometry: TraceGeometry,
        path: [TraceNode],
        pathColor: UIColor,
        highlight: [TraceNode]
    ) throws {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: sceneSize, format: format)
        let image = renderer.image { context in
            let ctx = context.cgContext
            TraceGameConfig.reference.backgroundColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: sceneSize))

            let highlighted = Set(highlight)
            func point(for node: TraceNode) -> CGPoint {
                let sk = geometry.position(for: node)
                return CGPoint(x: sk.x, y: sceneSize.height - sk.y)
            }
            for node in geometry.field.allNodes where !highlighted.contains(node) {
                drawDot(point(for: node), radius: geometry.nodeVisualRadius, color: TraceGameConfig.reference.inactiveNodeColor, in: ctx)
            }

            if path.count >= 2 {
                ctx.setStrokeColor(pathColor.cgColor)
                ctx.setLineWidth(geometry.lineWidth)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.setMiterLimit(1)
                let points = path.map(point(for:))
                ctx.move(to: points[0])
                for next in points.dropFirst() {
                    ctx.addLine(to: next)
                }
                ctx.strokePath()
            }

            for node in highlight {
                drawDot(point(for: node), radius: geometry.nodeVisualRadius, color: pathColor, in: ctx)
            }

            let score = "TRACE QA"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "AvenirNext-Heavy", size: 22) ?? UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55),
            ]
            (name as NSString).draw(at: CGPoint(x: 16, y: 24), withAttributes: attributes)
            (score as NSString).draw(at: CGPoint(x: 16, y: 52), withAttributes: attributes)
        }
        let url = outputDirectory.appendingPathComponent(name)
        guard let data = image.pngData() else {
            XCTFail("Failed to encode \(name)")
            return
        }
        try data.write(to: url, options: .atomic)
    }

    private func drawDot(_ center: CGPoint, radius: CGFloat, color: UIColor, in ctx: CGContext) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
