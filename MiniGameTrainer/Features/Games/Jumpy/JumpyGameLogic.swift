import CoreGraphics
import Foundation

final class JumpyGameLogic {
    enum State: Equatable { case running, paused, gameOver }

    let config: JumpyGameConfig
    private(set) var state: State = .running
    private(set) var playerPosition: JumpyGridPosition
    private(set) var facing: JumpyFacing = .up
    private(set) var hop: JumpyHop?
    private(set) var score: Int
    private(set) var cameraProgress: CGFloat = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var rows: [Int: JumpyWorldRow] = [:]
    private(set) var totalJumps = 0
    private(set) var forwardJumps = 0
    private(set) var sidewaysJumps = 0
    private(set) var backwardJumps = 0

    var difficultyScoreOverride: Int?
    var collisionDetectionEnabled = true
    private var generator: JumpyLaneGenerator
    private var highestGeneratedRow = -1
    private var events: [JumpyEvent] = []

    init(config: JumpyGameConfig = .reference) {
        self.config = config
        playerPosition = JumpyGridPosition(row: 0, column: config.columnCount / 2)
        score = max(0, config.startingScore)
        generator = JumpyLaneGenerator(config: config)
        reset()
    }

    var isFinished: Bool { state == .gameOver }
    var acceptsInput: Bool { state == .running && hop == nil }
    var minimumRetreatRow: Int {
        let anchorRows = config.cameraAnchorYRatio / config.rowHeightRatio
        return max(0, Int(ceil(cameraProgress - anchorRows)))
    }
    var playerWorldPoint: CGPoint { interpolatedPlayerPoint(for: hop) }
    var hopProgress: CGFloat {
        guard let hop else { return 0 }
        return CGFloat(min(max(hop.elapsed / max(config.hopDuration, 0.001), 0), 1))
    }

    func reset() {
        state = .running
        playerPosition = JumpyGridPosition(row: 0, column: config.columnCount / 2)
        facing = .up
        hop = nil
        score = max(0, config.startingScore)
        cameraProgress = 0
        elapsedTime = 0
        totalJumps = 0
        forwardJumps = 0
        sidewaysJumps = 0
        backwardJumps = 0
        rows.removeAll(keepingCapacity: true)
        events.removeAll(keepingCapacity: true)
        generator = JumpyLaneGenerator(config: config)
        highestGeneratedRow = -1
        maintainWorld()
    }

    @discardableResult
    func requestMove(_ move: JumpyMove) -> Bool {
        guard acceptsInput else { return false }
        var destination = playerPosition
        switch move {
        case .up: destination.row += 1
        case .down: destination.row -= 1
        case .left: destination.column -= 1
        case .right: destination.column += 1
        }
        guard destination.column >= 0, destination.column < config.columnCount,
              destination.row >= minimumRetreatRow else { return false }

        facing = switch move {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        }
        hop = JumpyHop(from: playerPosition, to: destination, move: move, elapsed: 0)
        totalJumps += 1
        switch move {
        case .up: forwardJumps += 1
        case .down: backwardJumps += 1
        case .left, .right: sidewaysJumps += 1
        }
        return true
    }

    func update(deltaTime: TimeInterval) {
        guard state == .running, deltaTime > 0 else { return }
        var remaining = min(deltaTime, config.maximumFrameDelta)
        while remaining > 1e-9, state == .running {
            var step = min(remaining, config.maximumSimulationStep)
            if let hop {
                let untilLanding = config.hopDuration - hop.elapsed
                if untilLanding > 1e-9 { step = min(step, untilLanding) }
            }
            if let untilWrap = timeUntilNextVehicleWrap(), untilWrap > 1e-9 {
                step = min(step, untilWrap)
            }
            simulate(step)
            remaining -= step
        }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
    }

    func drainEvents() -> [JumpyEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    func makeSummary() -> JumpySessionSummary {
        JumpySessionSummary(
            score: score,
            duration: elapsedTime,
            totalJumps: totalJumps,
            forwardJumps: forwardJumps,
            sidewaysJumps: sidewaysJumps,
            backwardJumps: backwardJumps
        )
    }

    func row(at worldRow: Int) -> JumpyWorldRow? { rows[worldRow] }

    func replaceRowsForTesting(_ newRows: [JumpyWorldRow]) {
        rows = Dictionary(uniqueKeysWithValues: newRows.map { ($0.worldRow, $0) })
        highestGeneratedRow = newRows.map(\.worldRow).max() ?? -1
    }

    func setPlayerForTesting(_ position: JumpyGridPosition, score: Int? = nil, camera: CGFloat? = nil) {
        playerPosition = position
        hop = nil
        if let score { self.score = score }
        if let camera { cameraProgress = camera }
    }

    private func simulate(_ deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        let playerBefore = playerWorldPoint
        let oldCenters = roadVehicleCenters()

        for key in rows.keys {
            guard case .road(var lane) = rows[key]?.kind else { continue }
            lane.advance(by: deltaTime, margin: config.trafficMargin)
            rows[key]?.kind = .road(lane)
        }

        var completedHop: JumpyHop?
        if var currentHop = hop {
            currentHop.elapsed = min(config.hopDuration, currentHop.elapsed + deltaTime)
            hop = currentHop
            if currentHop.elapsed >= config.hopDuration - 1e-9 { completedHop = currentHop }
        }
        let playerAfter = playerWorldPoint

        if collisionDetectionEnabled,
           collides(playerFrom: playerBefore, playerTo: playerAfter, oldCenters: oldCenters) {
            state = .gameOver
            hop = nil
            events.append(.collided)
            return
        }

        if let completedHop {
            playerPosition = completedHop.to
            hop = nil
            score = max(score, playerPosition.row)
            cameraProgress = max(cameraProgress, CGFloat(playerPosition.row))
            maintainWorld()
            events.append(.hopped)
        }
    }

    private func collides(
        playerFrom: CGPoint,
        playerTo: CGPoint,
        oldCenters: [Int: [CGFloat]]
    ) -> Bool {
        let playerSize = CGSize(
            width: config.playerWidthRatio * config.playerHitboxScale,
            height: config.playerHeightInRows * config.playerHitboxScale
        )
        let trackLength = 1 + config.trafficMargin * 2
        for row in rows.values {
            guard case .road(let lane) = row.kind else { continue }
            let before = oldCenters[lane.id] ?? lane.vehicleCenters(margin: config.trafficMargin)
            let after = lane.vehicleCenters(margin: config.trafficMargin)
            for index in 0..<min(before.count, after.count) {
                var endX = after[index]
                let rawDelta = endX - before[index]
                if lane.direction == .right, rawDelta < -trackLength / 2 { endX += trackLength }
                if lane.direction == .left, rawDelta > trackLength / 2 { endX -= trackLength }
                let vehicleSize = CGSize(
                    width: lane.vehicleWidth * config.vehicleHitboxScale,
                    height: config.vehicleHeightInRows * config.vehicleHitboxScale
                )
                if JumpyCollision.sweptAABB(
                    playerFrom: playerFrom,
                    playerTo: playerTo,
                    playerSize: playerSize,
                    vehicleFrom: CGPoint(x: before[index], y: CGFloat(lane.worldRow)),
                    vehicleTo: CGPoint(x: endX, y: CGFloat(lane.worldRow)),
                    vehicleSize: vehicleSize
                ) { return true }
                // Check the wrapped image on the opposite edge as well.
                if JumpyCollision.sweptAABB(
                    playerFrom: playerFrom,
                    playerTo: playerTo,
                    playerSize: playerSize,
                    vehicleFrom: CGPoint(x: before[index] - CGFloat(lane.direction.rawValue) * trackLength, y: CGFloat(lane.worldRow)),
                    vehicleTo: CGPoint(x: endX - CGFloat(lane.direction.rawValue) * trackLength, y: CGFloat(lane.worldRow)),
                    vehicleSize: vehicleSize
                ) { return true }
            }
        }
        return false
    }

    private func roadVehicleCenters() -> [Int: [CGFloat]] {
        var result: [Int: [CGFloat]] = [:]
        for row in rows.values {
            if case .road(let lane) = row.kind {
                result[lane.id] = lane.vehicleCenters(margin: config.trafficMargin)
            }
        }
        return result
    }

    private func timeUntilNextVehicleWrap() -> TimeInterval? {
        let lower = -config.trafficMargin
        let upper = 1 + config.trafficMargin
        var earliest: CGFloat?
        for row in rows.values {
            guard case .road(let lane) = row.kind, lane.speed > 1e-9 else { continue }
            for center in lane.vehicleCenters(margin: config.trafficMargin) {
                let distance = lane.direction == .right ? upper - center : center - lower
                guard distance > 1e-9 else { continue }
                let time = distance / lane.speed
                earliest = min(earliest ?? time, time)
            }
        }
        return earliest.map(TimeInterval.init)
    }

    private func interpolatedPlayerPoint(for hop: JumpyHop?) -> CGPoint {
        let base = normalizedPoint(playerPosition)
        guard let hop else { return base }
        let t = CGFloat(min(max(hop.elapsed / max(config.hopDuration, 0.001), 0), 1))
        let start = normalizedPoint(hop.from)
        let end = normalizedPoint(hop.to)
        return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
    }

    func normalizedPoint(_ position: JumpyGridPosition) -> CGPoint {
        let usable = 1 - config.horizontalMarginRatio * 2
        let x = config.horizontalMarginRatio + usable * (CGFloat(position.column) + 0.5) / CGFloat(config.columnCount)
        return CGPoint(x: x, y: CGFloat(position.row))
    }

    private func maintainWorld() {
        let target = max(playerPosition.row, score) + config.lookaheadRows
        while highestGeneratedRow < target {
            highestGeneratedRow += 1
            rows[highestGeneratedRow] = generator.nextRow(
                at: highestGeneratedRow,
                difficultyScore: difficultyScoreOverride
            )
        }
        let cullBelow = minimumRetreatRow - config.retainedRowsBehind
        rows = rows.filter { $0.key >= cullBelow }
    }
}
