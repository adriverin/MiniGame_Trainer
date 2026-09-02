import XCTest
@testable import MiniGameTrainer

final class PianoGameLogicTests: XCTestCase {
    private let sceneSize = CGSize(width: 393, height: 852)

    private func makeLogic(_ mutate: (inout PianoGameConfig) -> Void = { _ in }) -> PianoGameLogic {
        var config = PianoGameConfig.deterministic(seed: 42)
        mutate(&config)
        let logic = PianoGameLogic(config: config, sceneSize: sceneSize)
        logic.finishCountdown()
        logic.startPlaying()
        _ = logic.drainEvents()
        return logic
    }

    /// Advances the simulation in 60 Hz steps (respects the frame-delta clamp).
    private func advance(_ logic: PianoGameLogic, seconds: TimeInterval) {
        let step = 1.0 / 60.0
        var remaining = seconds
        while remaining > 1e-9 {
            let delta = min(step, remaining)
            logic.update(deltaTime: delta)
            remaining -= delta
        }
    }

    /// Scrolls until the lowest active tile is inside the playfield, then taps it.
    private func tapLowestTile(_ logic: PianoGameLogic) {
        var guardCounter = 0
        while lowestActiveTilePoint(logic).y < logic.geometry.playfieldTop, guardCounter < 1000 {
            logic.update(deltaTime: 1.0 / 60.0)
            guardCounter += 1
        }
        logic.handleTap(at: lowestActiveTilePoint(logic))
    }

    /// Centre of the lowest active tile, in screen-down coordinates.
    private func lowestActiveTilePoint(_ logic: PianoGameLogic) -> CGPoint {
        let row = logic.lowestActiveRow!
        let tile = row.tiles.first { $0.state == .active }!
        let frame = logic.geometry.tileFrame(lane: tile.lane, rowTop: row.top)
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: Initial layout

    func testInitialLayoutMatchesConfiguration() {
        let logic = makeLogic()
        let geometry = logic.geometry
        let visibleRows = logic.rows.filter { $0.bottom(rowHeight: geometry.rowHeight) > geometry.playfieldTop }
        XCTAssertEqual(visibleRows.count, logic.config.initialRowCount)

        let lowest = logic.rows.last!
        let expectedTop = geometry.playfieldTop + logic.config.initialLowestRowTopOffset * geometry.rowHeight
        XCTAssertEqual(lowest.top, expectedTop, accuracy: 0.001)

        // Rows are contiguous.
        for (upper, lower) in zip(logic.rows, logic.rows.dropFirst()) {
            XCTAssertEqual(lower.top - upper.top, geometry.rowHeight, accuracy: 0.001)
        }
        // One hidden row is kept above the playfield.
        XCTAssertLessThanOrEqual(logic.rows.first!.top, geometry.playfieldTop - geometry.rowHeight)
    }

    func testNoInputAcceptedBeforePlaying() {
        let logic = PianoGameLogic(config: .deterministic(), sceneSize: sceneSize)
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.handleTap(at: lowestActiveTilePoint(logic)), .ignored)
        XCTAssertEqual(logic.score, 0)

        logic.beginCountdown()
        XCTAssertEqual(logic.handleTap(at: lowestActiveTilePoint(logic)), .ignored)
        XCTAssertEqual(logic.score, 0)
    }

    func testTapToStartDoesNotConsumeTileByDefault() {
        let logic = PianoGameLogic(config: .deterministic(), sceneSize: sceneSize)
        logic.finishCountdown()
        XCTAssertEqual(logic.state, .waitingForStart)
        XCTAssertEqual(logic.handleTap(at: lowestActiveTilePoint(logic)), .started)
        XCTAssertEqual(logic.state, .playing)
        XCTAssertEqual(logic.score, 0)
    }

    // MARK: Score

    func testSuccessfulTapIncreasesScoreAndConsumesTile() {
        let logic = makeLogic()
        let point = lowestActiveTilePoint(logic)
        let outcome = logic.handleTap(at: point)
        guard case .hit(let tile) = outcome else {
            return XCTFail("Expected a hit, got \(outcome)")
        }
        XCTAssertEqual(tile.state, .hit)
        XCTAssertEqual(logic.score, logic.config.pointsPerTile)
        XCTAssertTrue(logic.drainEvents().contains(.scoreChanged(1)))

        // Tapping the consumed tile again is a wrong tap (reference: "empty space").
        XCTAssertEqual(logic.handleTap(at: point), .wrongTap)
        XCTAssertEqual(logic.state, .gameOver(.wrongTap))
    }

    func testPointsPerTileIsConfigurable() {
        let logic = makeLogic { $0.pointsPerTile = 3 }
        logic.handleTap(at: lowestActiveTilePoint(logic))
        XCTAssertEqual(logic.score, 3)
    }

    func testTapOnEmptyLaneEndsGame() {
        let logic = makeLogic()
        let row = logic.lowestActiveRow!
        let occupied = Set(row.tiles.map(\.lane))
        let emptyLane = (0..<logic.config.laneCount).first { !occupied.contains($0) }!
        let point = CGPoint(x: logic.geometry.laneCenterX(emptyLane), y: row.top + logic.geometry.rowHeight / 2)
        XCTAssertEqual(logic.handleTap(at: point), .wrongTap)
        XCTAssertEqual(logic.state, .gameOver(.wrongTap))
        XCTAssertTrue(logic.drainEvents().contains(.gameEnded(.wrongTap)))
    }

    func testTapAbovePlayfieldIsIgnored() {
        let logic = makeLogic()
        let point = CGPoint(x: 10, y: logic.geometry.playfieldTop / 2)
        XCTAssertEqual(logic.handleTap(at: point), .ignored)
        XCTAssertEqual(logic.state, .playing)
    }

    // MARK: Movement / spawning

    func testTilesMoveWithDeltaTimeAndColumnStaysContiguous() {
        let logic = makeLogic()
        let before = logic.rows.last!.top
        logic.update(deltaTime: 1.0 / 60.0)
        let expected = logic.speed / 60.0
        XCTAssertEqual(logic.rows.last!.top - before, expected, accuracy: 0.001)

        for _ in 0..<600 {
            logic.update(deltaTime: 1.0 / 120.0)
            if logic.state.isGameOver { break }
            for (upper, lower) in zip(logic.rows, logic.rows.dropFirst()) {
                XCTAssertEqual(lower.top - upper.top, logic.geometry.rowHeight, accuracy: 0.01)
            }
            XCTAssertLessThanOrEqual(logic.rows.first!.top, logic.geometry.playfieldTop - logic.geometry.rowHeight + 0.01)
        }
    }

    func testLargeFrameDeltaIsClamped() {
        let logic = makeLogic()
        let before = logic.rows.last!.top
        logic.update(deltaTime: 5)
        let travelled = logic.rows.last!.top - before
        XCTAssertEqual(travelled, logic.speed * CGFloat(logic.config.maximumFrameDelta), accuracy: 0.001)
    }

    func testFrameRateIndependence() {
        let a = makeLogic()
        let b = makeLogic()
        for _ in 0..<30 { a.update(deltaTime: 1.0 / 60.0) }
        for _ in 0..<60 { b.update(deltaTime: 1.0 / 120.0) }
        XCTAssertEqual(a.state, .playing)
        XCTAssertEqual(a.rows.last!.top, b.rows.last!.top, accuracy: 0.01)
        XCTAssertEqual(a.elapsedTime, b.elapsedTime, accuracy: 0.0001)
    }

    func testSpawnedLanesAreValidAndSinglesNeverRepeat() {
        let logic = makeLogic { $0.doubleTileProbability = 0 }
        var previousPrimary: Int?
        var seenRows = Set<Int>()
        for _ in 0..<2000 {
            // Keep the game alive by tapping the lowest tile before it can be missed.
            tapIfClose(logic)
            logic.update(deltaTime: 1.0 / 120.0)
            XCTAssertFalse(logic.state.isGameOver)
            for row in logic.rows.reversed() where !seenRows.contains(row.id) {
                seenRows.insert(row.id)
                XCTAssertEqual(row.tiles.count, 1)
                XCTAssertTrue((0..<logic.config.laneCount).contains(row.primaryLane))
                if let previousPrimary {
                    XCTAssertNotEqual(row.primaryLane, previousPrimary, "row \(row.id) repeated lane \(previousPrimary)")
                }
                previousPrimary = row.primaryLane
            }
        }
        XCTAssertGreaterThan(seenRows.count, 20)
    }

    func testDoubleTilesOnlyAfterUnlockScore() {
        let logic = makeLogic {
            $0.doubleTileUnlockScore = 5
            $0.doubleTileProbability = 1
        }
        // Before reaching the unlock score every spawned row has one tile.
        XCTAssertTrue(logic.rows.allSatisfy { $0.tiles.count == 1 })

        while logic.score < 5 {
            XCTAssertTrue(logic.rows.allSatisfy { $0.tiles.count == 1 })
            if logic.lowestActiveRow != nil {
                logic.handleTap(at: lowestActiveTilePoint(logic))
            }
            logic.update(deltaTime: 1.0 / 60.0)
            XCTAssertFalse(logic.state.isGameOver)
        }
        XCTAssertEqual(logic.score, 5)
        // Force spawns by scrolling one full row height.
        let steps = Int(ceil(logic.geometry.rowHeight / (logic.speed / 120)))
        for _ in 0..<steps {
            logic.update(deltaTime: 1.0 / 120.0)
        }
        let newest = logic.rows.first!
        XCTAssertEqual(newest.tiles.count, 2)
        XCTAssertEqual(Set(newest.tiles.map(\.lane)).count, 2)
    }

    func testDeterministicSeedReproducesLaneSequence() {
        let a = PianoGameLogic(config: .deterministic(seed: 7), sceneSize: sceneSize)
        let b = PianoGameLogic(config: .deterministic(seed: 7), sceneSize: sceneSize)
        XCTAssertEqual(a.rows.map(\.primaryLane), b.rows.map(\.primaryLane))
        let c = PianoGameLogic(config: .deterministic(seed: 8), sceneSize: sceneSize)
        var sequences: [[Int]] = []
        for logic in [a, b, c] {
            logic.finishCountdown()
            logic.startPlaying()
            var lanes: [Int] = []
            for _ in 0..<600 {
                tapIfClose(logic)
                logic.update(deltaTime: 1.0 / 60.0)
                for event in logic.drainEvents() {
                    if case .tileSpawned(let tile) = event { lanes.append(tile.lane) }
                }
            }
            XCTAssertFalse(logic.state.isGameOver)
            sequences.append(lanes)
        }
        XCTAssertGreaterThan(sequences[0].count, 10)
        XCTAssertEqual(sequences[0], sequences[1])
        XCTAssertNotEqual(sequences[0], sequences[2])
    }

    /// Taps the lowest active tile once it is in the lower half of its travel, keeping runs alive.
    private func tapIfClose(_ logic: PianoGameLogic) {
        guard let row = logic.lowestActiveRow else { return }
        let bottom = row.bottom(rowHeight: logic.geometry.rowHeight)
        if bottom > logic.geometry.missLineY - logic.geometry.rowHeight * 0.5 {
            logic.handleTap(at: lowestActiveTilePoint(logic))
        }
    }

    // MARK: Miss

    func testMissedTileEndsGame() {
        let logic = makeLogic()
        var frames = 0
        while !logic.state.isGameOver && frames < 5000 {
            logic.update(deltaTime: 1.0 / 60.0)
            frames += 1
        }
        XCTAssertEqual(logic.state, .gameOver(.missedTile))
        let events = logic.drainEvents()
        XCTAssertTrue(events.contains { if case .tileMissed = $0 { return true } else { return false } })
        XCTAssertTrue(events.contains(.gameEnded(.missedTile)))

        // The missed tile's bottom edge is at (or just past) the miss line.
        let missed = logic.rows.flatMap(\.tiles).first { $0.state == .missed }!
        let row = logic.rows.first { $0.id == missed.rowIndex }!
        let bottom = row.bottom(rowHeight: logic.geometry.rowHeight)
        XCTAssertGreaterThanOrEqual(bottom, logic.geometry.missLineY)
        XCTAssertLessThan(bottom - logic.geometry.missLineY, logic.speed / 60 + 0.01)

        // Frozen: further updates do nothing.
        let top = logic.rows.last!.top
        logic.update(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(logic.rows.last!.top, top)
        XCTAssertEqual(logic.handleTap(at: lowestActiveTilePoint(logic)), .ignored)
    }

    func testTopEdgeMissRuleWaitsForFullExit() {
        let logic = makeLogic { $0.missRule = .topEdgeCrossesMissLine }
        var frames = 0
        while !logic.state.isGameOver && frames < 5000 {
            logic.update(deltaTime: 1.0 / 60.0)
            frames += 1
        }
        let missed = logic.rows.flatMap(\.tiles).first { $0.state == .missed }!
        let row = logic.rows.first { $0.id == missed.rowIndex }!
        XCTAssertGreaterThanOrEqual(row.top, logic.geometry.missLineY)
    }

    func testTimerEndConditionDoesNotEndOnMistakes() {
        let logic = makeLogic { $0.endCondition = .timer(2) }
        while logic.elapsedTime < 1.5 {
            logic.update(deltaTime: 1.0 / 60.0)
        }
        XCTAssertEqual(logic.state, .playing)
        while logic.elapsedTime < 2.1 && !logic.state.isGameOver {
            logic.update(deltaTime: 1.0 / 60.0)
        }
        XCTAssertEqual(logic.state, .gameOver(.timerExpired))
        XCTAssertGreaterThan(logic.makeSummary().missedTiles, 0)
    }

    // MARK: Reset

    func testResetRestoresInitialState() {
        let logic = makeLogic()
        for _ in 0..<3 {
            tapLowestTile(logic)
            advance(logic, seconds: 0.1)
        }
        XCTAssertEqual(logic.score, 3)
        XCTAssertGreaterThan(logic.elapsedTime, 0)
        let fastSpeed = logic.speed

        logic.reset()
        XCTAssertEqual(logic.state, .ready)
        XCTAssertEqual(logic.score, 0)
        XCTAssertEqual(logic.elapsedTime, 0)
        XCTAssertLessThan(logic.speed, fastSpeed)
        XCTAssertEqual(logic.speed, logic.difficulty.speed(forScore: 0, geometry: logic.geometry))
        XCTAssertTrue(logic.rows.allSatisfy { $0.tiles.allSatisfy { $0.state == .active } })
        XCTAssertEqual(logic.makeSummary().correctTaps, 0)

        let fresh = PianoGameLogic(config: logic.config, sceneSize: sceneSize)
        XCTAssertEqual(logic.rows.map(\.top), fresh.rows.map(\.top))
        XCTAssertEqual(logic.rows.map(\.primaryLane), fresh.rows.map(\.primaryLane), "seeded reset replays the same sequence")
    }

    // MARK: Pause

    func testPauseStopsMovementAndResumeRestoresState() {
        let logic = makeLogic()
        logic.pause()
        XCTAssertEqual(logic.state, .paused)
        let top = logic.rows.last!.top
        logic.update(deltaTime: 0.5)
        XCTAssertEqual(logic.rows.last!.top, top)
        XCTAssertEqual(logic.handleTap(at: lowestActiveTilePoint(logic)), .ignored)
        logic.resume()
        XCTAssertEqual(logic.state, .playing)
    }

    // MARK: Performance summary

    func testSummaryTracksReactionTimesAndAccuracy() {
        let logic = makeLogic()
        advance(logic, seconds: 0.25)
        logic.handleTap(at: lowestActiveTilePoint(logic))
        advance(logic, seconds: 0.15)
        logic.handleTap(at: lowestActiveTilePoint(logic))
        while !logic.state.isGameOver {
            logic.update(deltaTime: 1.0 / 60.0)
        }
        let summary = logic.makeSummary()
        XCTAssertEqual(summary.correctTaps, 2)
        XCTAssertEqual(summary.missedTiles, 1)
        XCTAssertEqual(summary.wrongTaps, 0)
        XCTAssertEqual(summary.accuracy!, 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(summary.bestReactionTime!, 0.25, accuracy: 0.0001)
        XCTAssertEqual(summary.averageReactionTime!, (0.25 + 0.4) / 2, accuracy: 0.0001)
        XCTAssertEqual(summary.medianReactionTime!, (0.25 + 0.4) / 2, accuracy: 0.0001)
        XCTAssertEqual(summary.reason, .missedTile)
        XCTAssertGreaterThan(summary.peakSpeed, 0)
    }
}
