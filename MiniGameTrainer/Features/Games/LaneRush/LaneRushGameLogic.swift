import CoreGraphics
import Foundation

enum LaneRushCollision {
  static func sweptImpactFraction(
    playerFrom: Double,
    playerTo: Double,
    trafficLane: Double,
    trafficFrom: Double,
    trafficTo: Double,
    collisionDistance: Double,
    lateralHalfExtent: Double,
    longitudinalHalfExtent: Double
  ) -> Double? {
    let startX = playerFrom - trafficLane
    let endX = playerTo - trafficLane
    let startY = collisionDistance - trafficFrom
    let endY = collisionDistance - trafficTo

    if abs(startX) <= lateralHalfExtent, abs(startY) <= longitudinalHalfExtent {
      return 0
    }

    var entry = 0.0
    var exit = 1.0
    for (origin, delta, halfExtent) in [
      (startX, endX - startX, lateralHalfExtent),
      (startY, endY - startY, longitudinalHalfExtent),
    ] {
      if abs(delta) < 1e-12 {
        if abs(origin) > halfExtent { return nil }
        continue
      }
      let first = (-halfExtent - origin) / delta
      let second = (halfExtent - origin) / delta
      entry = max(entry, min(first, second))
      exit = min(exit, max(first, second))
      if entry > exit { return nil }
    }
    guard exit >= 0, entry <= 1 else { return nil }
    return min(1, max(0, entry))
  }
}

final class LaneRushGameLogic {
  let config: LaneRushGameConfig
  let speedModel: LaneRushDifficultyModel
  let trafficDifficulty: LaneRushTrafficDifficultyModel

  private(set) var state: LaneRushGameState = .running
  private(set) var distanceMeters: Double = 0
  private(set) var roadMarkings = LaneRushRoadMarkingFlow()
  private(set) var player = LaneRushPlayerController()
  private(set) var trafficWaves: [LaneRushTrafficWave] = []
  private(set) var activeDuration: TimeInterval = 0
  private(set) var carsPassed = 0
  private(set) var laneChanges = 0
  private(set) var maximumSpeed: Double = 0
  private(set) var failureElapsed: TimeInterval = 0
  private(set) var maximumActiveWaves = 0
  private(set) var maximumActiveCars = 0
  private var trafficGenerator: LaneRushTrafficGenerator
  private var events: [LaneRushGameEvent] = []

  var collisionDetectionEnabled = true
  var difficultyDistanceOverride: Double?

  init(
    config: LaneRushGameConfig = .reference,
    speedModel: LaneRushDifficultyModel = .reference,
    trafficDifficulty: LaneRushTrafficDifficultyModel = .init()
  ) {
    self.config = config
    self.speedModel = speedModel
    self.trafficDifficulty = trafficDifficulty
    trafficGenerator = LaneRushTrafficGenerator(config: config, difficulty: trafficDifficulty)
    reset()
  }

  var score: Int { Int(floor(distanceMeters)) }
  var currentSpeed: Double { speedModel.forwardSpeed(at: distanceMeters) }
  var trafficClosingSpeed: Double { currentSpeed * config.oncomingFactor }
  var acceptsInput: Bool { state == .running }
  var isFinished: Bool { state == .finished }
  var failureProgress: CGFloat {
    guard state == .failing || state == .pausedFailing || state == .finished else { return 0 }
    return CGFloat(min(1, failureElapsed / max(0.001, config.failureDelay)))
  }
  var renderState: LaneRushRenderState {
    LaneRushRenderState(
      score: score,
      roadMarkings: roadMarkings.distancesAhead,
      player: player,
      vehicles: trafficWaves.flatMap { wave in
        wave.obstacles.map {
          LaneRushRenderedVehicle(
            id: $0.id,
            lane: $0.lane,
            distanceAhead: wave.distanceAhead,
            appearance: $0.appearance)
        }
      },
      state: state,
      failureProgress: failureProgress)
  }

  func reset() {
    state = .running
    distanceMeters = max(0, config.startingDistance.isFinite ? config.startingDistance : 0)
    roadMarkings = LaneRushRoadMarkingFlow(playerDistance: distanceMeters)
    player = LaneRushPlayerController()
    trafficWaves.removeAll(keepingCapacity: true)
    activeDuration = 0
    carsPassed = 0
    laneChanges = 0
    maximumSpeed = currentSpeed
    failureElapsed = 0
    maximumActiveWaves = 0
    maximumActiveCars = 0
    events.removeAll(keepingCapacity: true)
    trafficGenerator = LaneRushTrafficGenerator(config: config, difficulty: trafficDifficulty)
    maintainTraffic()
  }

  @discardableResult
  func requestLaneChange(_ command: LaneRushLaneCommand) -> Bool {
    guard state == .running else { return false }
    return player.command(command)
  }

  func update(deltaTime: TimeInterval) {
    guard deltaTime.isFinite, deltaTime > 0 else { return }
    if state == .failing {
      failureElapsed += min(deltaTime, config.maximumFrameDelta)
      if failureElapsed >= config.failureDelay {
        failureElapsed = config.failureDelay
        state = .finished
        events.append(.finished)
      }
      return
    }
    guard state == .running else { return }

    var remaining = min(deltaTime, config.maximumFrameDelta)
    while remaining > 1e-9, state == .running {
      let step = min(remaining, config.maximumSimulationStep)
      simulate(step)
      remaining -= step
    }
  }

  func pause() {
    switch state {
    case .running: state = .paused
    case .failing: state = .pausedFailing
    default: break
    }
  }

  func resume() {
    switch state {
    case .paused: state = .running
    case .pausedFailing: state = .failing
    default: break
    }
  }

  func drainEvents() -> [LaneRushGameEvent] {
    defer { events.removeAll(keepingCapacity: true) }
    return events
  }

  func makeSummary() -> LaneRushSessionSummary {
    LaneRushSessionSummary(
      distance: score,
      carsPassed: carsPassed,
      laneChanges: laneChanges,
      duration: activeDuration,
      maximumSpeed: maximumSpeed)
  }

  func nearestUpcomingSafeLane(maximumDistance: Double = 82) -> LaneRushLane? {
    trafficWaves
      .filter { $0.distanceAhead > config.collisionDistance && $0.distanceAhead <= maximumDistance }
      .min { $0.distanceAhead < $1.distanceAhead }?
      .safeLane
  }

  func replaceTrafficForTesting(_ waves: [LaneRushTrafficWave]) {
    trafficWaves = waves
  }

  func setPlayerForTesting(_ controller: LaneRushPlayerController) {
    player = controller
  }

  #if DEBUG
    func offsetTrafficForDebug(by distance: Double) {
      guard distance.isFinite, distance > 0 else { return }
      for index in trafficWaves.indices {
        trafficWaves[index].distanceAhead -= distance
      }
    }
  #endif

  private func simulate(_ deltaTime: TimeInterval) {
    let speed = currentSpeed
    let playerForwardDelta = speed * deltaTime
    let closingDelta = playerForwardDelta * config.oncomingFactor
    let playerBefore = player
    var playerAfter = player
    playerAfter.update(deltaTime: deltaTime)

    var firstImpact: Double?
    if collisionDetectionEnabled {
      for wave in trafficWaves {
        let trafficAfter = wave.distanceAhead - closingDelta
        for obstacle in wave.obstacles {
          guard
            let fraction = LaneRushCollision.sweptImpactFraction(
              playerFrom: Double(playerBefore.lateralPosition),
              playerTo: Double(playerAfter.lateralPosition),
              trafficLane: Double(obstacle.lane.lateral),
              trafficFrom: wave.distanceAhead,
              trafficTo: trafficAfter,
              collisionDistance: config.collisionDistance,
              lateralHalfExtent: config.playerHalfWidth + config.vehicleHalfWidth,
              longitudinalHalfExtent: config.longitudinalHalfExtent)
          else { continue }
          firstImpact = min(firstImpact ?? fraction, fraction)
        }
      }
    }

    let appliedFraction = firstImpact ?? 1
    let appliedTime = deltaTime * appliedFraction
    let appliedPlayerDelta = playerForwardDelta * appliedFraction
    distanceMeters += appliedPlayerDelta
    activeDuration += appliedTime
    maximumSpeed = max(maximumSpeed, speed)
    roadMarkings.advance(by: appliedPlayerDelta)
    player = playerBefore
    player.update(deltaTime: appliedTime)
    if player.lane != playerBefore.lane { laneChanges += 1 }
    for index in trafficWaves.indices {
      trafficWaves[index].distanceAhead -= closingDelta * appliedFraction
    }

    if firstImpact != nil {
      player.clearPendingCommand()
      state = .failing
      failureElapsed = 0
      events.append(.collided)
      return
    }

    cullPassedTraffic()
    maintainTraffic()
  }

  private func cullPassedTraffic() {
    var survivors: [LaneRushTrafficWave] = []
    survivors.reserveCapacity(trafficWaves.count)
    for wave in trafficWaves {
      if wave.distanceAhead < config.trafficCullDistance {
        carsPassed += wave.obstacles.count
      } else {
        survivors.append(wave)
      }
    }
    trafficWaves = survivors
  }

  private func maintainTraffic() {
    let difficultyDistance = difficultyDistanceOverride ?? distanceMeters
    let closingSpeed = speedModel.forwardSpeed(at: difficultyDistance) * config.oncomingFactor
    let generationDistance = max(
      config.minimumGenerationDistance,
      closingSpeed * config.generationLeadTime)

    if trafficWaves.isEmpty {
      let firstDistance = config.trafficVisibleDistance
      trafficWaves.append(
        trafficGenerator.makeWave(
          distanceAhead: firstDistance,
          precedingGap: firstDistance - config.collisionDistance,
          playerDistance: difficultyDistance,
          closingSpeed: closingSpeed))
    }

    while let farthest = trafficWaves.map(\.distanceAhead).max(), farthest < generationDistance {
      let spacing = trafficGenerator.spacing(at: difficultyDistance)
      trafficWaves.append(
        trafficGenerator.makeWave(
          distanceAhead: farthest + spacing,
          precedingGap: spacing,
          playerDistance: difficultyDistance,
          closingSpeed: closingSpeed))
    }
    maximumActiveWaves = max(maximumActiveWaves, trafficWaves.count)
    maximumActiveCars = max(
      maximumActiveCars,
      trafficWaves.reduce(0) { $0 + $1.obstacles.count })
  }
}
