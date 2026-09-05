import CoreGraphics
import XCTest
@testable import MiniGameTrainer

enum TraceLogicHarness {
    static let sceneSize = CGSize(width: 393, height: 852)

    static let radiusOneFourNodePath = [
        TraceNode(q: 0, r: 0),
        TraceNode(q: 1, r: 0),
        TraceNode(q: 1, r: -1),
        TraceNode(q: 0, r: -1),
    ]

    static func makeLogic(
        pattern: [TraceNode]? = nil,
        field: TraceHexField? = nil,
        seed: UInt64 = 42,
        skipPresentation: Bool = true,
        mutate: (inout TraceGameConfig) -> Void = { _ in }
    ) -> TraceGameLogic {
        var config = TraceGameConfig.reference
        config.sessionDuration = 0
        config.segmentRevealDuration = 0
        config.patternHoldDuration = 0
        config.evaluationDuration = 0
        config.transitionDuration = 0
        mutate(&config)
        let logic = TraceGameLogic(config: config, sceneSize: sceneSize, seed: seed)
        logic.skipPresentation = skipPresentation
        logic.forcedField = field
        logic.forcedPattern = pattern
        logic.forcedTargetCount = pattern?.count
        logic.start()
        if skipPresentation {
            XCTAssertEqual(logic.phase, .awaitingTrace)
        }
        return logic
    }

    static func completeCurrentPattern(_ logic: TraceGameLogic) {
        let target = logic.targetSequence
        XCTAssertFalse(target.isEmpty)
        for node in target {
            let result = logic.accept(node)
            if case .accepted = result { continue }
            XCTFail("Expected to accept \(node), got \(result)")
            return
        }
    }

    static func advanceToRecall(_ logic: TraceGameLogic, limit: Int = 40) {
        var steps = 0
        while logic.phase != .awaitingTrace, logic.phase != .gameOver, steps < limit {
            logic.update(deltaTime: 0.05)
            steps += 1
        }
        XCTAssertTrue(logic.phase == .awaitingTrace || logic.phase == .gameOver)
    }

    static func wrongNeighbor(after node: TraceNode, expected: TraceNode, field: TraceHexField) -> TraceNode {
        let candidate = TraceHexNeighbors.neighbors(of: node)
            .first { field.contains($0) && $0 != expected && $0 != node }
        return candidate ?? expected
    }
}
