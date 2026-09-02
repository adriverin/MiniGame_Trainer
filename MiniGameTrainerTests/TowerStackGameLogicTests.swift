import XCTest
@testable import MiniGameTrainer

final class TowerStackGameLogicTests: XCTestCase {
    private func makeLogic(_ mutate: (inout TowerStackGameConfig) -> Void = { _ in }) -> TowerStackGameLogic {
        var config = TowerStackGameConfig.reference
        mutate(&config)
        let logic = TowerStackGameLogic(config: config)
        logic.startPlaying()
        _ = logic.drainEvents()
        return logic
    }

    // MARK: Start sequence

    func testInitialStateShowsHintWithSlidingBlockAndFirstTapOnlyDismissesIt() {
        let logic = TowerStackGameLogic(config: .reference)
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.score, 0)
        XCTAssertTrue(logic.placedBlocks.isEmpty)
        XCTAssertEqual(logic.towerTop, TowerStackGameConfig.reference.initialFootprint)
        let start = logic.movingBlock!.position
        logic.update(deltaTime: 0.2)
        XCTAssertNotEqual(logic.movingBlock!.position, start, "Block slides while the hint is shown")
        XCTAssertEqual(logic.elapsedTime, 0, "Play time starts after the hint")

        XCTAssertNil(logic.placeBlock())
        XCTAssertEqual(logic.state, .playing)
        XCTAssertEqual(logic.score, 0)
        XCTAssertTrue(logic.placedBlocks.isEmpty)
    }

    func testFirstBlockSpawnsAtFarEndOfFirstAxisMovingTowardCamera() {
        let logic = makeLogic()
        let block = logic.movingBlock!
        let farSign = logic.cameraRig.farSign(along: .x)
        XCTAssertEqual(block.axis, .x)
        XCTAssertEqual(block.position, farSign * logic.config.movementRange, accuracy: 1e-9)
        XCTAssertEqual(block.direction, -farSign)
        XCTAssertEqual(block.speed, logic.difficulty.speed(forScore: 0))
        XCTAssertEqual(block.footprint.width, 1)
        XCTAssertEqual(block.footprint.depth, 1)
    }

    func testSpawnFromNearEndReversesInitialHeading() {
        let logic = makeLogic { $0.spawnFromFarEnd = false }
        let block = logic.movingBlock!
        let farSign = logic.cameraRig.farSign(along: .x)
        XCTAssertEqual(block.position, -farSign * logic.config.movementRange, accuracy: 1e-9)
        XCTAssertEqual(block.direction, farSign)
    }

    func testFirstBlockMissScoresZero() {
        let logic = makeLogic()
        let placement = logic.placeBlock(atOffset: 1.5)!
        XCTAssertTrue(placement.isMiss)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertTrue(logic.placedBlocks.isEmpty)
    }

    // MARK: Placement

    func testPerfectPlacementScoresOnePointAndKeepsFootprint() {
        let logic = makeLogic()
        let placement = logic.placeBlock(atOffset: 0)!
        XCTAssertFalse(placement.isMiss)
        XCTAssertEqual(placement.overlapRatio, 1, accuracy: 1e-9)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.placedBlocks.count, 1)
        XCTAssertEqual(logic.towerTop.width, 1, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.depth, 1, accuracy: 1e-9)
        let events = logic.drainEvents()
        XCTAssertTrue(events.contains(.scoreChanged(1)))
        XCTAssertTrue(events.contains(.blockSpawned))
        XCTAssertFalse(events.contains { if case .pieceCut = $0 { return true } else { return false } })
    }

    func testAxesAlternateAndOnlyActiveAxisIsTrimmed() {
        let logic = makeLogic()
        XCTAssertEqual(logic.movingBlock?.axis, .x)
        logic.placeBlock(atOffset: 0.1)
        XCTAssertEqual(logic.towerTop.width, 0.9, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.depth, 1.0, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.centerX, 0.05, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.centerZ, 0, accuracy: 1e-9)

        XCTAssertEqual(logic.movingBlock?.axis, .z)
        logic.placeBlock(atOffset: -0.2)
        XCTAssertEqual(logic.towerTop.width, 0.9, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.depth, 0.8, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.centerX, 0.05, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.centerZ, -0.1, accuracy: 1e-9)

        XCTAssertEqual(logic.movingBlock?.axis, .x)
        logic.placeBlock(atOffset: 0)
        XCTAssertEqual(logic.movingBlock?.axis, .z)
        XCTAssertEqual(logic.score, 3)
    }

    func testMovingBlockInheritsTrimmedFootprintAndPathCentresOnTowerTop() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0.1)
        logic.placeBlock(atOffset: 0.1)
        let block = logic.movingBlock!
        XCTAssertEqual(block.footprint.width, 0.9, accuracy: 1e-9)
        XCTAssertEqual(block.footprint.depth, 0.9, accuracy: 1e-9)
        XCTAssertEqual(block.footprint.centerZ, logic.towerTop.centerZ, accuracy: 1e-9, "Non-moving axis stays aligned")
        let center = logic.towerTop.center(along: block.axis)
        XCTAssertEqual(block.minimum, center - logic.config.movementRange, accuracy: 1e-9)
        XCTAssertEqual(block.maximum, center + logic.config.movementRange, accuracy: 1e-9)
    }

    func testAccumulatedShrinkageCompounds() {
        let logic = makeLogic()
        var expectedWidth: CGFloat = 1
        for _ in 0..<6 {
            let block = logic.movingBlock!
            let dimension = logic.towerTop.dimension(along: block.axis)
            logic.placeBlock(atOffset: 0.05 * dimension)
            if block.axis == .x {
                expectedWidth *= 0.95
                XCTAssertEqual(logic.towerTop.width, expectedWidth, accuracy: 1e-9)
            }
        }
        XCTAssertEqual(logic.towerTop.width, 0.95 * 0.95 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(logic.towerTop.depth, 0.95 * 0.95 * 0.95, accuracy: 1e-9)
        XCTAssertEqual(logic.score, 6)
    }

    func testImperfectPlacementEmitsCutPieceOnOverhangSide() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0.25)
        let cuts = logic.drainEvents().compactMap { event -> TowerStackCutPiece? in
            if case .pieceCut(let piece) = event { return piece } else { return nil }
        }
        XCTAssertEqual(cuts.count, 1)
        XCTAssertEqual(cuts[0].footprint.width, 0.25, accuracy: 1e-9)
        XCTAssertEqual(cuts[0].footprint.minX, 0.5, accuracy: 1e-9)
        XCTAssertEqual(cuts[0].side, 1)
        XCTAssertEqual(cuts[0].axis, .x)
        XCTAssertEqual(cuts[0].layer, 0)
    }

    func testCompleteMissEndsGameWithoutScoring() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0)
        let placement = logic.placeBlock(atOffset: 1.2)!
        XCTAssertTrue(placement.isMiss)
        XCTAssertEqual(logic.state, .gameOver)
        XCTAssertEqual(logic.score, 1)
        XCTAssertEqual(logic.placedBlocks.count, 1)
        XCTAssertNil(logic.movingBlock)
        XCTAssertTrue(logic.drainEvents().contains(.gameEnded(.missedTower)))
        XCTAssertNil(logic.placeBlock(atOffset: 0), "No input after game over")
        XCTAssertEqual(logic.makeSummary().score, 1)
    }

    func testPauseStopsMovementAndResumeContinues() {
        let logic = makeLogic()
        logic.pause()
        let position = logic.movingBlock!.position
        logic.update(deltaTime: 0.5)
        XCTAssertEqual(logic.movingBlock!.position, position)
        XCTAssertNil(logic.placeBlock(), "Taps are ignored while paused")
        logic.resume()
        XCTAssertEqual(logic.state, .playing)
        logic.update(deltaTime: 0.1)
        XCTAssertNotEqual(logic.movingBlock!.position, position)
    }

    func testLargeDeltaIsClamped() {
        let logic = makeLogic()
        let before = logic.movingBlock!
        logic.update(deltaTime: 5)
        let expected = before.advanced(by: logic.config.maximumDeltaTime)
        XCTAssertEqual(logic.movingBlock!.position, expected.position, accuracy: 1e-9)
    }

    // MARK: Touch timestamp

    func testTouchTimestampAdvancesBlockBeforeEvaluation() {
        let logic = makeLogic()
        let block = logic.movingBlock!
        let extra: TimeInterval = 0.05
        let expected = block.advanced(by: extra)
        let placement = logic.placeBlock(advancingBy: extra)!
        XCTAssertEqual(placement.incomingCenter, expected.position, accuracy: 1e-9)
        XCTAssertEqual(placement.offset, expected.position - 0, accuracy: 1e-9)
    }

    func testTouchTimestampIsEquivalentToFrameSimulation() {
        let stale = makeLogic()
        let advanced = makeLogic()
        // Bring the block near the tower so the placement is valid, using identical frame histories.
        for _ in 0..<50 {
            stale.update(deltaTime: 1.0 / 60)
            advanced.update(deltaTime: 1.0 / 60)
        }
        let staleResult = stale.placeBlock(advancingBy: 0)!
        stale.update(deltaTime: 0.02)
        let advancedResult = advanced.placeBlock(advancingBy: 0.02)!
        XCTAssertNotEqual(staleResult.incomingCenter, advancedResult.incomingCenter)
        XCTAssertEqual(
            advancedResult.incomingCenter - staleResult.incomingCenter,
            0.02 * advancedResult.movementSpeed * advancedResult.direction,
            accuracy: 1e-9
        )
    }

    private func simulate(_ logic: TowerStackGameLogic, seconds: TimeInterval, hz: Double = 120) {
        let frames = Int((seconds * hz).rounded(.up))
        for _ in 0..<frames { logic.update(deltaTime: 1 / hz) }
    }

    // MARK: Camera

    func testCameraTargetFollowsTowerTopAndEasesWithinStepDuration() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0.1)
        XCTAssertEqual(logic.cameraTarget.y, logic.config.blockHeight, accuracy: 1e-9)
        XCTAssertEqual(logic.cameraTarget.x, 0.05, accuracy: 1e-9)
        XCTAssertEqual(logic.cameraPosition.y, 0, accuracy: 1e-9, "Camera starts easing on the next frame")
        let duration = logic.difficulty.cameraStepDuration(forScore: 1)
        let halfFrames = Int((duration * 120 / 2).rounded(.down))
        for _ in 0..<halfFrames { logic.update(deltaTime: 1.0 / 120) }
        let progress = CGFloat(Double(halfFrames) / 120 / duration)
        let eased = progress * progress * (3 - 2 * progress)
        XCTAssertEqual(logic.cameraPosition.y, logic.config.blockHeight * eased, accuracy: 1e-6, "Smoothstep easing")
        XCTAssertGreaterThan(logic.cameraPosition.y, 0)
        XCTAssertLessThan(logic.cameraPosition.y, logic.config.blockHeight)
        simulate(logic, seconds: duration)
        XCTAssertEqual(logic.cameraPosition, logic.cameraTarget)
    }

    // MARK: Session summary

    func testSummaryAggregatesPrecisionMetrics() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0)
        logic.placeBlock(atOffset: 0.1)
        logic.placeBlock(atOffset: 0.5)
        let summary = logic.makeSummary()
        XCTAssertEqual(summary.score, 3)
        XCTAssertEqual(summary.placements, 3)
        XCTAssertEqual(summary.bestOverlapRatio ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(summary.worstOverlapRatio ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(summary.averageOverlapRatio ?? 0, (1 + 0.9 + 0.5) / 3, accuracy: 1e-9)
        XCTAssertEqual(summary.nearPerfectPlacements, 1)
        XCTAssertEqual(summary.finalWidthRatio, 0.5, accuracy: 1e-9)
        XCTAssertEqual(summary.finalDepthRatio, 0.9, accuracy: 1e-9)
        XCTAssertEqual(summary.highestSpeed, logic.difficulty.speed(forScore: 2), accuracy: 1e-9)
    }

    @MainActor
    func testResultBuilderUsesGenericScorePresentation() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0)
        let result = TowerStackResultBuilder.makeResult(from: logic.makeSummary())
        XCTAssertEqual(result.gameID, TowerStackGameModule.descriptor.id)
        XCTAssertEqual(result.score, 1)
        XCTAssertEqual(result.scorePresentation, .points)
        XCTAssertTrue(result.metrics.contains { $0.key == "averageOverlap" })
        XCTAssertTrue(GameRegistry.modules.contains { $0.descriptor.id == "towerStack" })
    }

    // MARK: Long run

    func testTwoHundredPlusDeterministicPlacementsStayNumericallyValid() {
        let logic = makeLogic()
        let frame: TimeInterval = 1.0 / 120
        var maxCameraLag: CGFloat = 0
        for index in 0..<220 {
            // Alternate a 1 % offset on either side so both axes shrink slowly like a good player.
            let block = logic.movingBlock!
            let dimension = logic.towerTop.dimension(along: block.axis)
            let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            // Simulate frames until the block passes the desired position, then place analytically.
            let desired = logic.towerTop.center(along: block.axis) + sign * 0.01 * dimension
            var frames = 0
            while logic.movingBlock!.timeToReach(desired).map({ $0 > frame }) ?? true, frames < 5_000 {
                logic.update(deltaTime: frame)
                frames += 1
            }
            let time = logic.movingBlock!.timeToReach(desired)!
            let placement = logic.placeBlock(advancingBy: time)!
            XCTAssertFalse(placement.isMiss, "Placement \(index) missed")
            XCTAssertTrue(logic.towerTop.isNumericallyValid)
            XCTAssertLessThan(logic.movingBlock!.speed, logic.config.maximumSpeed + 1e-9)
            maxCameraLag = max(maxCameraLag, abs(logic.cameraTarget.y - logic.cameraPosition.y))
            _ = logic.drainEvents()
        }
        XCTAssertEqual(logic.score, 220)
        XCTAssertEqual(logic.placedBlocks.count, 220)
        XCTAssertEqual(logic.towerTop.width, pow(0.99, 110), accuracy: 1e-6)
        XCTAssertEqual(logic.towerTop.depth, pow(0.99, 110), accuracy: 1e-6)
        XCTAssertGreaterThan(logic.towerTop.width, logic.config.minimumViableDimension)
        XCTAssertLessThanOrEqual(maxCameraLag, logic.config.blockHeight * 2, "Camera never falls more than two layers behind")
        XCTAssertEqual(logic.towerTopHeight, 220 * logic.config.blockHeight, accuracy: 1e-9)
        XCTAssertEqual(logic.movingBlock!.layer, 220)
        XCTAssertGreaterThan(logic.movingBlock!.speed, logic.difficulty.speed(forScore: 173))
        XCTAssertTrue(logic.movingBlock!.footprint.isNumericallyValid)
        XCTAssertTrue(logic.cameraPosition.y.isFinite)
    }

    func testFiveHundredPerfectPlacementsRemainStable() {
        let logic = makeLogic()
        for _ in 0..<500 {
            logic.placeBlock(atOffset: 0)
            simulate(logic, seconds: 0.5)
            _ = logic.drainEvents()
        }
        XCTAssertEqual(logic.score, 500)
        XCTAssertEqual(logic.towerTop.width, 1, accuracy: 1e-9)
        XCTAssertEqual(logic.movingBlock!.speed, logic.config.maximumSpeed)
        XCTAssertEqual(logic.cameraPosition, logic.cameraTarget)
        XCTAssertEqual(logic.cameraPosition.y, 500 * logic.config.blockHeight, accuracy: 1e-6)
    }

    func testResetRestoresInitialConditions() {
        let logic = makeLogic()
        logic.placeBlock(atOffset: 0.3)
        logic.placeBlock(atOffset: 0.3)
        logic.reset()
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.towerTop, logic.config.initialFootprint)
        XCTAssertEqual(logic.movingBlock?.axis, logic.config.firstAxis)
        XCTAssertEqual(logic.cameraPosition, .zero)
        XCTAssertTrue(logic.placedBlocks.isEmpty)
    }
}
