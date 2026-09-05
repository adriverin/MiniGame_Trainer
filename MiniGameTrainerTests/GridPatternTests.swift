import XCTest
@testable import MiniGameTrainer

final class GridPatternTests: XCTestCase {
    func testGeneratorNeverRepeatsACellAndHonoursCount() {
        var generator = SeededRandomNumberGenerator(seed: 99)
        for level in 1...10 {
            let size = GridDifficultyModel.gridSize(forLevel: level)
            let count = GridDifficultyModel.targetCount(forLevel: level, rows: size.rows, columns: size.columns)
            let pattern = GridDifficultyModel.generatePattern(
                rows: size.rows,
                columns: size.columns,
                count: count,
                generator: &generator
            )
            XCTAssertEqual(pattern.count, count)
            XCTAssertEqual(Set(pattern).count, count)
        }
    }

    func testEveryCoordinateStaysInsideBounds() {
        var generator = SeededRandomNumberGenerator(seed: 123)
        for _ in 0..<200 {
            let rows = Int.random(in: 2...7, using: &generator)
            let columns = Int.random(in: 2...7, using: &generator)
            let count = Int.random(in: 1...(rows * columns - 1), using: &generator)
            let pattern = GridDifficultyModel.generatePattern(
                rows: rows,
                columns: columns,
                count: count,
                generator: &generator
            )
            XCTAssertTrue(pattern.allSatisfy { (0..<rows).contains($0.row) && (0..<columns).contains($0.column) })
        }
    }

    func testSameSeedAndConfigReproduceTheSamePattern() {
        func pattern(seed: UInt64) -> Set<GridCell> {
            var generator = SeededRandomNumberGenerator(seed: seed)
            return GridDifficultyModel.generatePattern(rows: 5, columns: 5, count: 13, generator: &generator)
        }
        XCTAssertEqual(pattern(seed: 42), pattern(seed: 42))
        XCTAssertNotEqual(pattern(seed: 42), pattern(seed: 43))
    }

    func testQualityAssurancePatternIsTopLeftCenterBottomRight() {
        XCTAssertEqual(
            GridDifficultyModel.qualityAssurancePattern,
            [GridCell(row: 0, column: 0), GridCell(row: 1, column: 1), GridCell(row: 2, column: 2)]
        )
        var generator = SeededRandomNumberGenerator(seed: 1)
        let forced = GridDifficultyModel.generatePattern(
            rows: 3,
            columns: 3,
            count: 8,
            generator: &generator,
            forced: GridDifficultyModel.qualityAssurancePattern
        )
        XCTAssertEqual(forced, GridDifficultyModel.qualityAssurancePattern)
    }

    func testLogicSeedReplaysTheOpeningPattern() {
        let first = GridGameLogic(config: .reference, seed: 11)
        first.start(at: 0)
        let second = GridGameLogic(config: .reference, seed: 11)
        second.start(at: 0)
        XCTAssertEqual(first.targetCells, second.targetCells)
        let other = GridGameLogic(config: .reference, seed: 12)
        other.start(at: 0)
        XCTAssertNotEqual(first.targetCells, other.targetCells)
    }

    func testTargetCountMatchesDifficultyForEachLevel() {
        var generator = GridPatternGenerator(seed: 4)
        for level in 1...15 {
            let size = GridDifficultyModel.gridSize(forLevel: level)
            let count = GridDifficultyModel.targetCount(forLevel: level, rows: size.rows, columns: size.columns)
            let pattern = generator.nextPattern(rows: size.rows, columns: size.columns, count: count)
            XCTAssertEqual(pattern.count, count, "Level \(level) should request \(count) cells")
            XCTAssertEqual(Set(pattern).count, count)
        }
    }

    func testSuccessivePatternsCanVary() {
        var generator = GridPatternGenerator(seed: 21)
        var patterns: [Set<GridCell>] = []
        for _ in 0..<8 {
            patterns.append(generator.nextPattern(rows: 3, columns: 3, count: 4))
        }
        XCTAssertGreaterThan(Set(patterns).count, 1)
    }

    func testImmediateRepeatIsAvoidedWhenAlternativesExist() {
        var probe = GridPatternGenerator(seed: 77)
        let opening = probe.nextPattern(rows: 3, columns: 3, count: 4)

        var generator = GridPatternGenerator(seed: 77)
        generator.preloadRecent([opening])
        let next = generator.nextPattern(rows: 3, columns: 3, count: 4)
        XCTAssertNotEqual(next, opening)
        XCTAssertEqual(next.count, 4)
    }

    func testSameInjectedSeedReplaysTheSameSeries() {
        func series(seed: UInt64) -> [Set<GridCell>] {
            var generator = GridPatternGenerator(seed: seed)
            return (0..<6).map { _ in generator.nextPattern(rows: 4, columns: 4, count: 6) }
        }
        XCTAssertEqual(series(seed: 2026), series(seed: 2026))
        XCTAssertNotEqual(series(seed: 2026), series(seed: 2027))
    }

    func testMaximumDifficultyRemainsValidAtCapacity() {
        var generator = GridPatternGenerator(seed: 3)
        let full = generator.nextPattern(rows: 7, columns: 7, count: 49)
        XCTAssertEqual(full.count, 49)
        XCTAssertEqual(Set(full).count, 49)
        XCTAssertTrue(full.allSatisfy { (0..<7).contains($0.row) && (0..<7).contains($0.column) })

        let almostFull = generator.nextPattern(rows: 7, columns: 7, count: 48)
        XCTAssertEqual(almostFull.count, 48)
        XCTAssertEqual(Set(almostFull).count, 48)

        let again = generator.nextPattern(rows: 7, columns: 7, count: 49)
        XCTAssertEqual(again, full)
    }

    func testDifficultyProgressionFollowsReferenceSchedule() {
        let expected: [(level: Int, rows: Int, columns: Int, targets: Int)] = [
            (1, 3, 3, 4),
            (2, 3, 3, 6),
            (3, 4, 4, 6),
            (4, 4, 4, 12),
            (5, 5, 5, 13),
            (6, 5, 5, 19),
            (7, 6, 6, 17),
            (8, 6, 6, 20),
            (9, 6, 6, 23),
            (10, 7, 7, 28),
        ]
        for sample in expected {
            let stage = GridDifficultyModel.stage(forLevel: sample.level, config: .reference)
            XCTAssertEqual(stage.rows, sample.rows, "Level \(sample.level) rows")
            XCTAssertEqual(stage.columns, sample.columns, "Level \(sample.level) columns")
            XCTAssertEqual(stage.targetCount, sample.targets, "Level \(sample.level) targets")
            XCTAssertEqual(stage.presentationDuration, GridGameConfig.reference.presentationDuration)
            XCTAssertEqual(stage.recallTimeout, GridGameConfig.reference.recallTimeout)
        }
        XCTAssertEqual(GridDifficultyModel.targetCount(forLevel: 11, rows: 7, columns: 7), 30)
        XCTAssertEqual(GridDifficultyModel.targetCount(forLevel: 19, rows: 7, columns: 7), 46)
        XCTAssertEqual(GridDifficultyModel.targetCount(forLevel: 20, rows: 7, columns: 7), 48)
        XCTAssertEqual(GridDifficultyModel.targetCount(forLevel: 30, rows: 7, columns: 7), 48)
    }

    func testProductionSessionDoesNotPinAFixedSeed() {
        XCTAssertNil(GridDebugOptions.none.seed)
        XCTAssertNil(GridDebugOptions().seed)
        let production = GridGameLogic(config: .reference)
        XCTAssertFalse(production.usesInjectedSeed)
        let injected = GridGameLogic(config: .reference, seed: 9)
        XCTAssertTrue(injected.usesInjectedSeed)
    }

    func testRecentHistoryIsSuppressedWhenCombinationsRemain() {
        var probe = GridPatternGenerator(seed: 88)
        let recent = (0..<3).map { _ in probe.nextPattern(rows: 3, columns: 3, count: 4) }

        var generator = GridPatternGenerator(seed: 88)
        generator.preloadRecent(recent)
        let next = generator.nextPattern(rows: 3, columns: 3, count: 4)
        XCTAssertFalse(recent.contains(next))
        XCTAssertEqual(next.count, 4)
    }

    func testFullGridReusesTheOnlyPossiblePatternWithoutLooping() {
        var generator = GridPatternGenerator(seed: 1)
        let first = generator.nextPattern(rows: 2, columns: 2, count: 4)
        let second = generator.nextPattern(rows: 2, columns: 2, count: 4)
        XCTAssertEqual(first.count, 4)
        XCTAssertEqual(first, second)
        XCTAssertEqual(GridPatternGenerator.combinationCount(cells: 4, choose: 4), 1)
    }

    func testDistributionCoversEveryCellWithoutStructuralBias() {
        var generator = GridPatternGenerator(seed: 20260905)
        var appearances: [GridCell: Int] = [:]
        let rows = 4
        let columns = 4
        for row in 0..<rows {
            for column in 0..<columns {
                appearances[GridCell(row: row, column: column)] = 0
            }
        }
        let samples = 400
        for _ in 0..<samples {
            let pattern = generator.nextPattern(rows: rows, columns: columns, count: 6)
            for cell in pattern {
                appearances[cell, default: 0] += 1
            }
        }
        XCTAssertEqual(appearances.count, 16)
        XCTAssertTrue(appearances.values.allSatisfy { $0 > 0 }, "Every cell should appear in a 400-pattern 4×4 sample")
        let minimum = appearances.values.min() ?? 0
        let maximum = appearances.values.max() ?? 0
        XCTAssertGreaterThan(minimum, 0)
        XCTAssertLessThan(maximum, samples, "No cell should be selected in every pattern")
    }

    func testUnseededSessionUsesLevelTargetCountsAndAvoidsImmediateRepeats() {
        var config = GridGameConfig.reference
        config.presentationDuration = 0.05
        config.feedbackDuration = 0.05
        let logic = GridGameLogic(config: config)
        XCTAssertFalse(logic.usesInjectedSeed)
        var time: TimeInterval = 0
        logic.start(at: time)
        var previous: Set<GridCell>?
        for level in 1...5 {
            let expected = GridDifficultyModel.referenceTargetCounts[level]!
            XCTAssertEqual(logic.level, level)
            XCTAssertEqual(logic.targetCells.count, expected)
            if let previous {
                XCTAssertNotEqual(logic.targetCells, previous, "Level \(level) should not repeat the previous set")
            }
            previous = logic.targetCells
            time += logic.currentPresentationDuration + 0.001
            logic.update(at: time)
            logic.fillCorrectSelectionForDebug()
            XCTAssertEqual(logic.submit(), .submitted(correct: true))
            time += config.feedbackDuration + 0.001
            logic.update(at: time)
        }
    }
}
