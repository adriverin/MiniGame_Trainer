import CoreGraphics
import Foundation

final class ZigGameLogic {
    let config: ZigGameConfig
    private let difficulty: ZigDifficultyModel
    private var generator: ZigPathGenerator
    private(set) var state: ZigGameState = .running
    private(set) var ballPosition = CGPoint.zero
    private(set) var direction: ZigDirection = .positiveY
    private(set) var totalDistance: CGFloat = 0
    private(set) var score = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var turns = 0
    private(set) var maximumSpeed: CGFloat = 0
    private(set) var cameraProgress: CGFloat = 0
    private(set) var cells: Set<ZigCell> = []
    private(set) var fallElapsed: TimeInterval = 0
    private var highestGeneratedProgress = 2
    private var events: [ZigEvent] = []

    init(config: ZigGameConfig = .reference) {
        self.config = config
        difficulty = ZigDifficultyModel(config: config)
        generator = ZigPathGenerator(config: config)
        reset()
    }

    var acceptsInput: Bool { state == .running }
    var isFinished: Bool { state == .finished }
    var currentSpeed: CGFloat { difficulty.speed(forScore: score) }
    var renderState: ZigRenderState {
        ZigRenderState(ballPosition: ballPosition, direction: direction, cells: cells, score: score,
                       cameraProgress: cameraProgress, state: state,
                       fallProgress: CGFloat(min(1, fallElapsed / max(0.001, config.fallDuration))))
    }

    func reset() {
        state = .running
        ballPosition = .zero
        direction = .positiveY
        totalDistance = CGFloat(max(0, config.startingScore))
        score = max(0, config.startingScore)
        elapsedTime = 0
        turns = 0
        maximumSpeed = difficulty.speed(forScore: score)
        cameraProgress = 0
        fallElapsed = 0
        events.removeAll(keepingCapacity: true)
        cells.removeAll(keepingCapacity: true)
        generator = ZigPathGenerator(config: config)
        highestGeneratedProgress = 2
        maintainPath()
    }

    @discardableResult
    func toggleDirection() -> Bool {
        guard state == .running else { return false }
        direction = direction.toggled
        turns += 1
        events.append(.turned)
        return true
    }

    func update(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        if state == .falling {
            fallElapsed += min(deltaTime, config.maximumFrameDelta)
            if fallElapsed >= config.fallDuration {
                state = .finished
                events.append(.finished)
            }
            return
        }
        guard state == .running else { return }
        var remaining = min(deltaTime, config.maximumFrameDelta)
        while remaining > 1e-9, state == .running {
            let speed = currentSpeed
            maximumSpeed = max(maximumSpeed, speed)
            var step = min(remaining, config.maximumSimulationStep)
            let distanceToScore = CGFloat(score + 1) - totalDistance
            if distanceToScore > 1e-8 { step = min(step, TimeInterval(distanceToScore / speed)) }
            advance(step, speed: speed)
            remaining -= step
        }
    }

    func pause() {
        guard state == .running || state == .falling else { return }
        state = state == .falling ? .pausedFalling : .paused
    }

    func resume() {
        if state == .paused { state = .running }
        else if state == .pausedFalling { state = .falling }
    }

    func drainEvents() -> [ZigEvent] {
        defer { events.removeAll(keepingCapacity: true) }
        return events
    }

    func makeSummary() -> ZigSessionSummary {
        ZigSessionSummary(score: score, duration: elapsedTime, turns: turns, maximumSpeed: maximumSpeed)
    }

    func isSupported(_ point: CGPoint) -> Bool {
        if point.x >= -config.startingPadHalfWidth - config.supportTolerance,
           point.x <= config.startingPadHalfWidth + config.supportTolerance,
           point.y >= -config.startingPadBack - config.supportTolerance,
           point.y <= config.startingPadFront + config.supportTolerance { return true }
        let half = config.trackWidth / 2 + config.supportTolerance
        return cells.contains { abs(point.x - CGFloat($0.x)) <= half && abs(point.y - CGFloat($0.y)) <= half }
    }

    func replaceCellsForTesting(_ newCells: Set<ZigCell>) {
        cells = newCells
        highestGeneratedProgress = newCells.map(\.progress).max() ?? 2
    }

    @discardableResult
    func performPerfectTurnIfNeeded(lookahead: CGFloat = 0.35) -> Bool {
        guard state == .running, ballPosition.y >= config.startingPadFront - 0.5 else { return false }
        let current = ZigCell(x: Int(ballPosition.x.rounded()), y: Int(ballPosition.y.rounded()))
        let forward = direction == .positiveX
            ? ZigCell(x: current.x + 1, y: current.y)
            : ZigCell(x: current.x, y: current.y + 1)
        let alternate = direction == .positiveX
            ? ZigCell(x: current.x, y: current.y + 1)
            : ZigCell(x: current.x + 1, y: current.y)
        let axisPosition = direction == .positiveX ? ballPosition.x : ballPosition.y
        guard axisPosition - CGFloat(direction == .positiveX ? current.x : current.y) >= lookahead,
              !cells.contains(forward), cells.contains(alternate) else { return false }
        return toggleDirection()
    }

    func setBallForTesting(_ point: CGPoint, direction: ZigDirection? = nil, distance: CGFloat? = nil) {
        ballPosition = point
        if let direction { self.direction = direction }
        if let distance { totalDistance = distance; score = Int(floor(distance)) }
    }

    private func advance(_ deltaTime: TimeInterval, speed: CGFloat) {
        let movement = speed * CGFloat(deltaTime)
        let vector = direction.vector
        let start = ballPosition
        let destination = CGPoint(x: start.x + vector.dx * movement, y: start.y + vector.dy * movement)
        if isSupported(destination) {
            ballPosition = destination
            totalDistance += movement
            score = Int(floor(totalDistance + 1e-8))
            elapsedTime += deltaTime
            cameraProgress = max(cameraProgress, ballPosition.x + ballPosition.y)
            maintainPath()
            return
        }

        var low: CGFloat = 0
        var high: CGFloat = 1
        for _ in 0..<14 {
            let mid = (low + high) / 2
            let point = CGPoint(x: start.x + (destination.x - start.x) * mid,
                                y: start.y + (destination.y - start.y) * mid)
            if isSupported(point) { low = mid } else { high = mid }
        }
        ballPosition = CGPoint(x: start.x + (destination.x - start.x) * low,
                               y: start.y + (destination.y - start.y) * low)
        totalDistance += movement * low
        score = Int(floor(totalDistance + 1e-8))
        elapsedTime += deltaTime * TimeInterval(low)
        cameraProgress = max(cameraProgress, ballPosition.x + ballPosition.y)
        state = .falling
        fallElapsed = 0
        events.append(.fell)
    }

    private func maintainPath() {
        let target = Int(ceil(ballPosition.x + ballPosition.y)) + config.lookaheadUnits
        while highestGeneratedProgress < target {
            let cell = generator.nextCell(guaranteedStraightCells: config.guaranteedStraightCells)
            cells.insert(cell)
            highestGeneratedProgress = max(highestGeneratedProgress, cell.progress)
        }
        let cutoff = Int(floor(ballPosition.x + ballPosition.y)) - config.retainedUnitsBehind
        if cutoff > 3 { cells = cells.filter { $0.progress >= cutoff } }
    }
}
