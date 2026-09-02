import XCTest
@testable import MiniGameTrainer

final class TowerStackProjectionTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)
    private let config = TowerStackGameConfig.reference
    private lazy var projection = TowerStackProjection(sceneSize: sceneSize, config: config)

    func testFramedTargetProjectsToConfiguredScreenPosition() {
        let target = TowerStackWorldPoint(x: 0.3, y: 5, z: -0.2)
        let point = projection.project(target, camera: target)
        XCTAssertEqual(point.x, sceneSize.width / 2, accuracy: 1e-6)
        XCTAssertEqual(point.y, sceneSize.height * (1 - config.activeTopYRatio), accuracy: 1e-6)
    }

    func testUnitBlockTopFaceSpansConfiguredWidth() {
        let block = projection.projectBlock(config.initialFootprint, bottomY: -config.blockHeight, topY: 0, camera: .zero)
        let xs = block.top.map(\.x)
        XCTAssertEqual(xs.max()! - xs.min()!, config.topFaceWidthRatio * sceneSize.width, accuracy: 1e-6)
        // Diamond: far vertex above near vertex, symmetric about the centre.
        let ys = block.top.map(\.y)
        XCTAssertGreaterThan(ys.max()! - ys.min()!, 0)
        XCTAssertEqual((xs.max()! + xs.min()!) / 2, sceneSize.width / 2, accuracy: 0.5)
    }

    func testBlockHeightRendersThicknessBelowTopFace() {
        let block = projection.projectBlock(config.initialFootprint, bottomY: -config.blockHeight, topY: 0, camera: .zero)
        let topMinY = block.top.map(\.y).min()!
        let sideMinY = min(block.sideX.map(\.y).min()!, block.sideZ.map(\.y).min()!)
        XCTAssertLessThan(sideMinY, topMinY)
        // Reference: thickness ≈ 0.126 of the diamond width at the near vertical edge.
        let thickness = topMinY - sideMinY
        let diamondWidth = config.topFaceWidthRatio * sceneSize.width
        XCTAssertEqual(thickness / diamondWidth, 0.126, accuracy: 0.03)
    }

    func testFarBlockAppearsSmallerThanNearBlock() {
        let farSign = projection.rig.farSign(along: .x)
        let far = config.initialFootprint.moved(to: farSign * config.movementRange, along: .x)
        let near = config.initialFootprint.moved(to: -farSign * config.movementRange, along: .x)
        let farBlock = projection.projectBlock(far, bottomY: 0, topY: config.blockHeight, camera: .zero)
        let nearBlock = projection.projectBlock(near, bottomY: 0, topY: config.blockHeight, camera: .zero)
        func width(_ block: TowerStackProjectedBlock) -> CGFloat {
            let xs = block.top.map(\.x)
            return xs.max()! - xs.min()!
        }
        XCTAssertLessThan(width(farBlock), width(nearBlock))
        XCTAssertGreaterThan(farBlock.topCenter.y, nearBlock.topCenter.y, "Far blocks are higher on screen")
    }

    func testCameraMovingWithTowerKeepsFramingIdentical() {
        let low = projection.projectBlock(config.initialFootprint, bottomY: 0, topY: config.blockHeight, camera: .zero)
        let raised = TowerStackWorldPoint(x: 0, y: 40 * config.blockHeight, z: 0)
        let high = projection.projectBlock(
            config.initialFootprint, bottomY: raised.y, topY: raised.y + config.blockHeight, camera: raised
        )
        for (a, b) in zip(low.top, high.top) {
            XCTAssertEqual(a.x, b.x, accuracy: 1e-6)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-6)
        }
    }

    func testFirstAxisFarEndIsUpperRightLikeTheReference() {
        let farX = projection.rig.farSign(along: .x)
        let spawn = projection.project(TowerStackWorldPoint(x: farX * config.movementRange, y: 0, z: 0), camera: .zero)
        let center = projection.project(.zero, camera: .zero)
        XCTAssertGreaterThan(spawn.x, center.x, "Block 1 spawns to the right")
        XCTAssertGreaterThan(spawn.y, center.y, "…and above the tower")
        let farZ = projection.rig.farSign(along: .z)
        let spawnZ = projection.project(TowerStackWorldPoint(x: 0, y: 0, z: farZ * config.movementRange), camera: .zero)
        XCTAssertLessThan(spawnZ.x, center.x, "Block 2 spawns to the left")
        XCTAssertGreaterThan(spawnZ.y, center.y)
        // Screen path slope of the X axis ≈ ±0.6 in the reference.
        let slope = (spawn.y - center.y) / (spawn.x - center.x)
        XCTAssertEqual(abs(slope), 0.6, accuracy: 0.15)
    }

    func testSideFacesAreTheOnesFacingTheCamera() {
        let block = projection.projectBlock(config.initialFootprint, bottomY: 0, topY: config.blockHeight, camera: .zero)
        let nearX = projection.rig.nearSign(along: .x)
        let expectedCorners = [-0.5, 0.5].map { z in
            projection.project(TowerStackWorldPoint(x: nearX * 0.5, y: config.blockHeight, z: z), camera: .zero)
        }
        let topEdge = Array(block.sideX.prefix(2))
        for corner in expectedCorners {
            XCTAssertTrue(topEdge.contains { abs($0.x - corner.x) < 1e-6 && abs($0.y - corner.y) < 1e-6 })
        }
        XCTAssertTrue(block.sideXIsLeft, "With the camera at −X/+Z the X face is the left, darker one")
    }

    func testHueAdvancesFiveDegreesPerBlockAndWraps() {
        func hue(_ index: Int) -> CGFloat {
            var h: CGFloat = 0
            TowerStackPalette.colors(forBlockIndex: index, config: config).top.getHue(&h, saturation: nil, brightness: nil, alpha: nil)
            return h * 360
        }
        XCTAssertEqual(hue(0), 17, accuracy: 0.5)
        XCTAssertEqual(hue(10), 67, accuracy: 0.5)
        XCTAssertEqual(hue(72), 17, accuracy: 0.5)
        XCTAssertEqual(hue(172), hue(172 % 72), accuracy: 0.5)
    }
}
