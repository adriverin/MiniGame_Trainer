import XCTest
@testable import MiniGameTrainer

final class BloopyCollisionConsistencyTests: XCTestCase {
    private let sceneSize = CGSize(width: 390, height: 844)

    func testInactivePlatformCannotCollide() {
        let platform = BloopyPlatform(id: 3, worldX: 50, worldY: 20, width: 40, isActive: false)
        XCTAssertFalse(platform.isCollidable)
        let contact = BloopyPhysics.sweptTopLanding(
            previous: CGPoint(x: 50, y: 40),
            current: CGPoint(x: 50, y: 24),
            platform: platform,
            ballRadius: 8,
            platformHeight: 8,
            deltaTime: 1 / 60
        )
        XCTAssertNil(contact)
    }

    func testRemovedPlatformCannotCollide() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let platform = BloopyPlatform(id: 77, worldX: 195, worldY: 80, width: 60)
        logic.replacePlatformsForTesting([platform])
        logic.replacePlatformsForTesting([])
        let top = logic.geometry.platformTop(worldY: platform.worldY)
        logic.placeBallForTesting(
            position: CGPoint(x: platform.worldX, y: top + logic.geometry.ballRadius - 4),
            velocity: CGVector(dx: 0, dy: -200),
            previous: CGPoint(x: platform.worldX, y: top + logic.geometry.ballRadius + 20)
        )
        let before = logic.landingCount
        logic.update(deltaTime: 1 / 60)
        XCTAssertEqual(logic.landingCount, before)
        XCTAssertNil(logic.landingContact(
            from: CGPoint(x: platform.worldX, y: top + logic.geometry.ballRadius + 20),
            to: CGPoint(x: platform.worldX, y: top + logic.geometry.ballRadius - 4),
            deltaTime: 1 / 60
        ))
    }

    func testCulledPlatformCannotCollideAtOldPosition() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let stale = BloopyPlatform(id: 88, worldX: 180, worldY: 70, width: 64, isActive: false)
        let live = BloopyPlatform(id: 89, worldX: 200, worldY: 280, width: 64)
        logic.replacePlatformsForTesting([stale, live])
        let top = logic.geometry.platformTop(worldY: stale.worldY)
        let contact = logic.landingContact(
            from: CGPoint(x: stale.worldX, y: top + logic.geometry.ballRadius + 16),
            to: CGPoint(x: stale.worldX, y: top + logic.geometry.ballRadius - 6),
            deltaTime: 1 / 60
        )
        XCTAssertNil(contact)
    }

    func testLogicSkipsInactivePlatformsEvenIfStillInArray() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        let inactive = BloopyPlatform(id: 90, worldX: 195, worldY: 90, width: 70, isActive: false)
        logic.replacePlatformsForTesting([inactive])
        let top = logic.geometry.platformTop(worldY: inactive.worldY)
        logic.placeBallForTesting(
            position: CGPoint(x: inactive.worldX, y: top + logic.geometry.ballRadius - 4),
            velocity: CGVector(dx: 0, dy: -220),
            previous: CGPoint(x: inactive.worldX, y: top + logic.geometry.ballRadius + 18)
        )
        logic.update(deltaTime: 1 / 60)
        XCTAssertEqual(logic.landingCount, 0)
    }

    func testEveryActivePlatformIsCollidableAndRenderable() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        for _ in 0..<360 {
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            for platform in logic.platforms {
                XCTAssertTrue(platform.isActive)
                XCTAssertTrue(platform.isCollidable)
                XCTAssertTrue(platform.appearance == .peach || platform.appearance == .red)
            }
            XCTAssertEqual(logic.platforms.filter(\.isCollidable).count, logic.platforms.count)
        }
    }

    func testCulledPlatformsLeaveTheCollisionSet() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var seen = Set<Int>()
        var culled = Set<Int>()
        for _ in 0..<1_200 {
            for platform in logic.platforms { seen.insert(platform.id) }
            logic.applyAutoSteer()
            logic.update(deltaTime: 1 / 60)
            let live = Set(logic.platforms.map(\.id))
            culled.formUnion(seen.subtracting(live))
        }
        XCTAssertFalse(culled.isEmpty)
        for id in culled {
            XCTAssertFalse(logic.platforms.contains { $0.id == id })
        }
    }

    func testEveryLandingHasAnActiveVisiblePlatformUnderTheBall() {
        let logic = BloopyGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.start()
        var landings = 0
        for _ in 0..<2_400 {
            logic.applyAutoSteer()
            let before = logic.landingCount
            logic.update(deltaTime: 1 / 60)
            if logic.landingCount > before, let contact = logic.lastLanding {
                landings += 1
                let platform = logic.platforms.first { $0.id == contact.platformID }
                XCTAssertNotNil(platform, "bounce \(contact.platformID) had no live platform")
                XCTAssertEqual(platform?.isActive, true)
                XCTAssertEqual(platform?.isCollidable, true)
                XCTAssertTrue(
                    BloopyPhysics.horizontallyOverlaps(
                        ballX: contact.ballPosition.x,
                        platformX: platform!.worldX,
                        platformWidth: platform!.width,
                        ballRadius: logic.geometry.ballRadius
                    )
                )
                let screenTop = logic.geometry.screenY(
                    worldY: logic.geometry.platformTop(worldY: platform!.worldY),
                    cameraY: logic.cameraY
                )
                XCTAssertGreaterThanOrEqual(screenTop, -1)
                XCTAssertLessThan(screenTop, sceneSize.height + logic.geometry.platformHeight)
            }
        }
        XCTAssertGreaterThan(landings, 4)
    }

    @MainActor
    func testIntroCopyDoesNotMentionWrapping() {
        let text = [
            BloopyGameModule.descriptor.subtitle,
            BloopyGameModule.descriptor.instructions,
        ].joined(separator: " ").lowercased()
        XCTAssertFalse(text.contains("wrap"))
        XCTAssertFalse(text.contains("reappear"))
        XCTAssertTrue(text.contains("steer"))
        XCTAssertTrue(text.contains("bounc"))
        XCTAssertFalse(BloopyGameModule.descriptor.skills.contains("Spatial Wrap"))
    }
}
