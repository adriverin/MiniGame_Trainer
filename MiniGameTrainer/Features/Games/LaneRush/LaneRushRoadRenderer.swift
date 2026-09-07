import SwiftUI

#if DEBUG
  /// Deliberately static and DEBUG-only. Launch with -laneRushStaticRoad.
  /// No game session, attempt, input, traffic, timer or Results route is created.
  struct LaneRushStaticRoadView: View {
    let vehicleDepth: LaneRushVehicleDepth?
    let playerCheckpoint: LaneRushPlayerCheckpoint?
    let dynamicCheckpoint: LaneRushDynamicCheckpoint?
    @State private var player = LaneRushPlayerController()
    @State private var dynamic: LaneRushDynamicSimulation
    @State private var lastUpdate: Date?
    @Environment(\.scenePhase) private var scenePhase

    init(
      vehicleDepth: LaneRushVehicleDepth? = nil,
      playerCheckpoint: LaneRushPlayerCheckpoint? = nil,
      dynamicCheckpoint: LaneRushDynamicCheckpoint? = nil
    ) {
      self.vehicleDepth = vehicleDepth
      self.playerCheckpoint = playerCheckpoint
      self.dynamicCheckpoint = dynamicCheckpoint
      _dynamic = State(initialValue: dynamicCheckpoint?.simulation ?? LaneRushDynamicSimulation())
    }

    var body: some View {
      GeometryReader { proxy in
        TimelineView(.animation) { timeline in
          Canvas { context, size in
            let road = LaneRushStaticRoadGeometry(size: size)
            let controller: LaneRushPlayerController
            if let playerCheckpoint {
              controller = playerCheckpoint.controller
            } else if dynamicCheckpoint != nil {
              controller = dynamic.player
            } else {
              controller = player
            }
            let vehicles: [LaneRushRenderedVehicle]
            if dynamicCheckpoint != nil {
              vehicles = [
                LaneRushRenderedVehicle(
                  id: 0, lane: .center,
                  distanceAhead: dynamic.trafficDistanceAhead,
                  appearance: .orangeCoupe)
              ]
            } else if let vehicleDepth {
              vehicles = [
                LaneRushRenderedVehicle(
                  id: 0, lane: .center,
                  distanceAhead: Double(vehicleDepth.distanceAhead),
                  appearance: .orangeCoupe)
              ]
            } else {
              vehicles = []
            }
            LaneRushRoadRenderer(
              size: size,
              vehicles: vehicles,
              roadMarkings: dynamicCheckpoint == nil
                ? nil : dynamic.roadMarkings.distancesAhead,
              playerPresentation: controller.presentation(on: road),
              score: dynamicCheckpoint == nil ? 0 : dynamic.displayedDistance,
              failureProgress: 0
            ).draw(in: &context)
          }
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
              .onEnded { value in
                guard playerCheckpoint == nil,
                  let command = LaneRushGestureInterpreter().command(
                    start: value.startLocation,
                    end: value.location,
                    gameplayWidth: proxy.size.width)
                else { return }
                if dynamicCheckpoint != nil {
                  dynamic.command(command)
                } else {
                  player.command(command)
                }
              }
          )
          .onChange(of: timeline.date) { _, date in
            guard playerCheckpoint == nil else { return }
            if dynamicCheckpoint != nil {
              dynamic.update(at: date.timeIntervalSinceReferenceDate)
            } else if let lastUpdate {
              player.update(deltaTime: min(1.0 / 15.0, date.timeIntervalSince(lastUpdate)))
            }
            lastUpdate = date
          }
          .overlay(alignment: .topTrailing) {
            if dynamicCheckpoint != nil {
              Button {
                if dynamic.isPaused {
                  dynamic.resume(at: Date.timeIntervalSinceReferenceDate)
                } else {
                  dynamic.pause()
                }
              } label: {
                Image(systemName: dynamic.isPaused ? "play.fill" : "pause.fill")
                  .font(.system(size: 18, weight: .bold))
                  .foregroundStyle(.white)
                  .frame(width: 44, height: 44)
                  .background(.black.opacity(0.42), in: Circle())
              }
              .buttonStyle(.plain)
              .padding(.top, 58)
              .padding(.trailing, 20)
              .accessibilityLabel(dynamic.isPaused ? "Resume Lane Rush" : "Pause Lane Rush")
            }
          }
        }
      }
      .ignoresSafeArea()
      .statusBarHidden()
      .accessibilityLabel(accessibilityDescription)
      .onChange(of: scenePhase) { _, phase in
        if dynamicCheckpoint != nil, phase != .active { dynamic.pause() }
      }
    }

    private var accessibilityDescription: String {
      if dynamicCheckpoint != nil {
        return "LANE RUSH dynamic motion checkpoint. Score \(dynamic.displayedDistance) metres."
      }
      guard let vehicleDepth else {
        return "LANE RUSH static road checkpoint. Score zero metres."
      }
      return "LANE RUSH traffic projection checkpoint. One car at \(vehicleDepth.rawValue) depth."
    }
  }

#endif

struct LaneRushRoadRenderer {
  let size: CGSize
  let vehicles: [LaneRushRenderedVehicle]
  let roadMarkings: [Double]?
  let playerPresentation: LaneRushPlayerPresentation
  let score: Int
  let failureProgress: CGFloat
  private var geometry: LaneRushStaticRoadGeometry { .init(size: size) }

  func draw(in context: inout GraphicsContext) {
    drawBackground(in: &context)
    drawRoad(in: &context)
    for vehicle
      in vehicles
      .filter({ $0.distanceAhead <= Double(LaneRushVehicleProjection.visibleDistance) })
      .sorted(by: { $0.distanceAhead > $1.distanceAhead })
    {
      drawTrafficCar(vehicle, in: &context)
    }
    drawPlayer(playerPresentation, in: &context)
    drawScore(score, in: &context)
    drawFailureFeedback(in: &context)
  }

  private func drawBackground(in context: inout GraphicsContext) {
    context.fill(
      Path(CGRect(origin: .zero, size: size)),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: color(0x4D3278), location: 0),
          .init(color: color(0x53367E), location: 0.42),
          .init(color: color(0x97558F), location: 0.77),
          .init(color: color(0xDC758E), location: 1),
        ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: geometry.horizonY)))

    // Sun and halo are behind the skyline, never behind foreground road geometry.
    let sunCenter = CGPoint(x: size.width * 0.625, y: size.height * 0.472)
    ellipse(
      in: &context, center: sunCenter, width: size.width * 0.327,
      height: size.width * 0.327, fill: color(0xEAC2B3).opacity(0.34))
    ellipse(
      in: &context, center: sunCenter, width: size.width * 0.212,
      height: size.width * 0.218, fill: color(0xEAE1BF))

    cloud(in: &context, x: 0.29, y: 0.316, width: 0.255)
    cloud(in: &context, x: 0.82, y: 0.367, width: 0.207)
    cloud(in: &context, x: -0.035, y: 0.36, width: 0.12)

    // Original faceted mesa silhouettes, drawn in normalized screen coordinates.
    polygon(
      in: &context,
      points: [
        (-0.03, 0.598), (0.075, 0.585), (0.15, 0.547),
        (0.29, 0.552), (0.33, 0.532), (0.45, 0.523), (0.62, 0.527),
        (0.69, 0.55), (0.77, 0.559), (0.82, 0.587), (0.88, 0.564),
        (1.03, 0.572), (1.03, 0.675), (-0.03, 0.675),
      ], fill: color(0x74476F))
    polygon(
      in: &context,
      points: [
        (0.80, 0.586), (0.88, 0.566), (0.95, 0.577),
        (0.91, 0.637), (0.81, 0.651),
      ], fill: color(0x573454))
    polygon(
      in: &context,
      points: [
        (-0.02, 0.59), (0.08, 0.59), (0.15, 0.67),
        (-0.02, 0.675),
      ], fill: color(0x844C76))
    polygon(
      in: &context,
      points: [
        (0.06, 0.604), (0.12, 0.555), (0.28, 0.557),
        (0.31, 0.671), (0.09, 0.671),
      ], fill: color(0x935C86))
    polygon(
      in: &context,
      points: [
        (0.12, 0.555), (0.23, 0.56), (0.24, 0.671),
        (0.09, 0.671), (0.06, 0.604),
      ], fill: color(0x89567F))
    polygon(
      in: &context,
      points: [
        (0.24, 0.557), (0.34, 0.56), (0.35, 0.671),
        (0.25, 0.671),
      ], fill: color(0xA26894))
    polygon(
      in: &context,
      points: [
        (0.30, 0.551), (0.34, 0.532), (0.48, 0.537),
        (0.49, 0.672), (0.35, 0.672), (0.35, 0.555),
      ], fill: color(0x7D4B72))
    polygon(
      in: &context,
      points: [
        (0.48, 0.537), (0.62, 0.535), (0.68, 0.558),
        (0.74, 0.57), (0.82, 0.62), (0.80, 0.672), (0.49, 0.672),
      ], fill: color(0x89537D))
    polygon(
      in: &context,
      points: [
        (0.56, 0.569), (0.65, 0.57), (0.68, 0.673),
        (0.57, 0.673),
      ], fill: color(0x7C4871))
    polygon(
      in: &context,
      points: [
        (0.735, 0.604), (0.80, 0.592), (0.94, 0.608),
        (0.99, 0.674), (0.73, 0.674),
      ], fill: color(0x9D648E))
    polygon(
      in: &context,
      points: [
        (0.735, 0.604), (0.86, 0.61), (0.88, 0.674),
        (0.73, 0.674),
      ], fill: color(0x8E577F))

    context.fill(
      Path(
        CGRect(
          x: 0, y: geometry.horizonY, width: size.width,
          height: size.height - geometry.horizonY)),
      with: .color(color(0xD4AE61)))
    cactus(in: &context, x: 0.955, ground: 0.674, height: 0.071)
    cactus(in: &context, x: 0.055, ground: 0.693, height: 0.032)
  }

  private func drawRoad(in context: inout GraphicsContext) {
    let g = geometry
    let outline = path([
      g.point(lateral: -1.5, depth: 0), g.point(lateral: 1.5, depth: 0),
      g.point(lateral: 1.5, depth: 1), g.point(lateral: -1.5, depth: 1),
    ])
    context.fill(
      outline,
      with: .linearGradient(
        Gradient(colors: [color(0x392A2D), color(0x302425)]),
        startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.bottomY)))
    // Painted strips share the road's exact lateral/depth mapping.
    for edge: CGFloat in [-1.46, 1.46] {
      roadStrip(
        in: &context, lateral: edge, halfWidth: 0.018,
        from: 0, to: 1, fill: color(0xF1EADD))
    }
    if let roadMarkings {
      let projection = LaneRushRoadMarkingProjection(road: g)
      for divider: CGFloat in [-0.5, 0.5] {
        for distanceAhead in roadMarkings {
          guard let range = projection.depthRange(distanceAhead: distanceAhead) else { continue }
          roadStrip(
            in: &context, lateral: divider, halfWidth: 0.041,
            from: range.lowerBound, to: range.upperBound, fill: color(0xE9D991))
        }
      }
    } else {
      let dashes: [(CGFloat, CGFloat)] = [
        (0.005, 0.017), (0.051, 0.077),
        (0.15, 0.207), (0.34, 0.45), (0.69, 0.96),
      ]
      for divider: CGFloat in [-0.5, 0.5] {
        for (start, end) in dashes {
          roadStrip(
            in: &context, lateral: divider, halfWidth: 0.041,
            from: start, to: end, fill: color(0xE9D991))
        }
      }
    }
  }

  private func roadStrip(
    in context: inout GraphicsContext, lateral: CGFloat,
    halfWidth: CGFloat, from start: CGFloat, to end: CGFloat, fill: Color
  ) {
    let g = geometry
    context.fill(
      path([
        g.point(lateral: lateral - halfWidth, depth: start),
        g.point(lateral: lateral + halfWidth, depth: start),
        g.point(lateral: lateral + halfWidth, depth: end),
        g.point(lateral: lateral - halfWidth, depth: end),
      ]), with: .color(fill))
  }

  private func drawPlayer(
    _ presentation: LaneRushPlayerPresentation,
    in context: inout GraphicsContext
  ) {
    let frame = presentation.frame
    var car = context
    let failureLean = min(1, failureProgress * 2.4) * 14
    car.translateBy(
      x: frame.midX + failureProgress * frame.width * 0.055,
      y: frame.midY + failureProgress * frame.height * 0.025)
    car.rotate(by: .degrees(presentation.leanDegrees + failureLean))
    car.translateBy(x: -frame.width / 2, y: -frame.height / 2)
    car.scaleBy(x: frame.width, y: frame.height)
    // Rear view: tires behind wide fenders, roof and sloped rear glass above the trunk.
    car.fill(
      Path(ellipseIn: CGRect(x: 0.01, y: 0.86, width: 0.98, height: 0.15)),
      with: .color(.black.opacity(0.28)))
    car.fill(
      Path(CGRect(x: 0.06, y: 0.57, width: 0.13, height: 0.41)), with: .color(color(0x12191A)))
    car.fill(
      Path(CGRect(x: 0.81, y: 0.57, width: 0.13, height: 0.41)), with: .color(color(0x12191A)))
    car.fill(
      Path(CGRect(x: 0.07, y: 0.63, width: 0.035, height: 0.30)), with: .color(color(0x283331)))
    car.fill(
      Path(CGRect(x: 0.895, y: 0.63, width: 0.035, height: 0.30)), with: .color(color(0x283331)))
    unitPolygon(
      in: &car,
      points: [
        (0.115, 0.05), (0.23, 0.05), (0.23, 0.37),
        (0.07, 0.37),
      ], hex: 0x009E80)
    unitPolygon(
      in: &car,
      points: [
        (0.77, 0.05), (0.885, 0.05), (0.93, 0.37),
        (0.77, 0.37),
      ], hex: 0x008B72)
    unitPolygon(
      in: &car,
      points: [
        (0.04, 0.46), (0.95, 0.46), (1, 0.82),
        (0.91, 0.94), (0.09, 0.94), (0, 0.82),
      ], hex: 0x008E74)
    unitPolygon(
      in: &car,
      points: [
        (0.21, 0), (0.79, 0), (0.89, 0.70),
        (0.11, 0.70),
      ], hex: 0x2DB392)
    unitPolygon(
      in: &car,
      points: [
        (0.21, 0), (0.79, 0), (0.83, 0.28),
        (0.17, 0.28),
      ], hex: 0x36BA9B)
    unitPolygon(
      in: &car,
      points: [
        (0.435, 0.055), (0.565, 0.055), (0.575, 0.265),
        (0.425, 0.265),
      ], hex: 0xE3D8AD)
    unitPolygon(
      in: &car,
      points: [
        (0.18, 0.29), (0.82, 0.29), (0.80, 0.56),
        (0.20, 0.56),
      ], hex: 0x166A61)
    unitPolygon(
      in: &car,
      points: [
        (0.205, 0.325), (0.795, 0.325), (0.78, 0.545),
        (0.22, 0.545),
      ], hex: 0x23333F)
    unitPolygon(
      in: &car,
      points: [
        (0.205, 0.325), (0.795, 0.325), (0.792, 0.35),
        (0.21, 0.35),
      ], hex: 0x334953)
    unitPolygon(
      in: &car,
      points: [
        (0.13, 0.62), (0.87, 0.62), (0.90, 0.73),
        (0.10, 0.73),
      ], hex: 0x16A184)
    unitPolygon(
      in: &car,
      points: [
        (0.145, 0.57), (0.855, 0.57), (0.868, 0.665),
        (0.132, 0.665),
      ], hex: 0xDACEAB)
    unitPolygon(
      in: &car,
      points: [
        (0.132, 0.665), (0.868, 0.665), (0.866, 0.706),
        (0.134, 0.706),
      ], hex: 0xB6AC8F)
    unitPolygon(
      in: &car,
      points: [
        (0.02, 0.79), (0.98, 0.79), (0.90, 0.91),
        (0.10, 0.91),
      ], hex: 0x00836C)
    car.fill(
      Path(CGRect(x: 0.10, y: 0.875, width: 0.80, height: 0.09)), with: .color(color(0xD4C9A7)))
    car.fill(
      Path(CGRect(x: 0.10, y: 0.948, width: 0.80, height: 0.025)), with: .color(color(0xA89F87)))
    for x: CGFloat in [0.26, 0.74] {
      car.fill(
        Path(ellipseIn: CGRect(x: x - 0.052, y: 0.768, width: 0.104, height: 0.131)),
        with: .color(color(0xE87C56)))
    }
    car.fill(
      Path(CGRect(x: 0.43, y: 0.705, width: 0.14, height: 0.035)), with: .color(color(0xD9CEAD)))
  }

  private func drawTrafficCar(
    _ vehicle: LaneRushRenderedVehicle,
    in context: inout GraphicsContext
  ) {
    let projection = LaneRushVehicleProjection(road: geometry)
    let frame = projection.vehicleFrame(
      lane: vehicle.lane.lateral,
      distanceAhead: CGFloat(vehicle.distanceAhead))
    let bodyHex = vehicle.appearance.color.bodyHex
    let darkHex = vehicle.appearance.color.darkHex
    var car = context
    car.translateBy(x: frame.minX, y: frame.minY)
    car.scaleBy(x: frame.width, y: frame.height)

    // Front-facing low-poly coupe. The long hood and headlights distinguish it
    // from the player's compact rear view even when rendered near the horizon.
    car.fill(
      Path(ellipseIn: CGRect(x: 0.05, y: 0.88, width: 0.90, height: 0.12)),
      with: .color(.black.opacity(0.27)))
    car.fill(
      Path(
        roundedRect: CGRect(x: 0.025, y: 0.42, width: 0.12, height: 0.49),
        cornerRadius: 0.025), with: .color(color(0x171718)))
    car.fill(
      Path(
        roundedRect: CGRect(x: 0.855, y: 0.42, width: 0.12, height: 0.49),
        cornerRadius: 0.025), with: .color(color(0x171718)))
    unitPolygon(
      in: &car,
      points: [
        (0.17, 0.10), (0.83, 0.10), (0.91, 0.48),
        (0.09, 0.48),
      ], hex: darkHex)
    unitPolygon(
      in: &car,
      points: [
        (0.23, 0.13), (0.77, 0.13), (0.82, 0.36),
        (0.18, 0.36),
      ], hex: 0x21333D)
    unitPolygon(
      in: &car,
      points: [
        (0.23, 0.13), (0.77, 0.13), (0.755, 0.165),
        (0.245, 0.165),
      ], hex: 0x344B55)
    unitPolygon(
      in: &car,
      points: [
        (0.09, 0.47), (0.91, 0.47), (0.98, 0.84),
        (0.88, 0.93), (0.12, 0.93), (0.02, 0.84),
      ], hex: bodyHex)
    unitPolygon(
      in: &car,
      points: [
        (0.15, 0.49), (0.85, 0.49), (0.79, 0.76),
        (0.21, 0.76),
      ], hex: darkHex)
    unitPolygon(
      in: &car,
      points: [
        (0.405, 0.52), (0.595, 0.52), (0.61, 0.70),
        (0.39, 0.70),
      ], hex: 0x211B1C)
    unitPolygon(
      in: &car,
      points: [
        (0.42, 0.54), (0.58, 0.54), (0.59, 0.585),
        (0.41, 0.585),
      ], hex: 0x332124)
    car.fill(
      Path(
        roundedRect: CGRect(x: 0.075, y: 0.035, width: 0.85, height: 0.075),
        cornerRadius: 0.018), with: .color(color(0x211719)))
    car.fill(
      Path(CGRect(x: 0.145, y: 0.075, width: 0.045, height: 0.12)),
      with: .color(color(0x271C1D)))
    car.fill(
      Path(CGRect(x: 0.81, y: 0.075, width: 0.045, height: 0.12)),
      with: .color(color(0x271C1D)))
    if vehicle.appearance.body == .utility {
      unitPolygon(
        in: &car,
        points: [(0.29, 0.015), (0.47, 0.015), (0.47, 0.12), (0.29, 0.12)],
        hex: 0xC8893E)
      unitPolygon(
        in: &car,
        points: [(0.50, 0.005), (0.69, 0.005), (0.69, 0.12), (0.50, 0.12)],
        hex: 0xE2AE59)
    }
    for x: CGFloat in [0.255, 0.745] {
      car.fill(
        Path(
          ellipseIn: CGRect(
            x: x - 0.065, y: 0.735,
            width: 0.13, height: 0.13)),
        with: .color(color(0xF0E7C9)))
      car.fill(
        Path(
          ellipseIn: CGRect(
            x: x - 0.034, y: 0.766,
            width: 0.068, height: 0.068)),
        with: .color(color(0xFFF6D8)))
    }
    unitPolygon(
      in: &car,
      points: [
        (0.10, 0.855), (0.90, 0.855), (0.86, 0.94),
        (0.14, 0.94),
      ], hex: 0xDDD2B5)
    unitPolygon(
      in: &car,
      points: [
        (0.14, 0.94), (0.86, 0.94), (0.83, 0.975),
        (0.17, 0.975),
      ], hex: 0xAEA58F)
  }

  private func drawScore(_ score: Int, in context: inout GraphicsContext) {
    let digit = context.resolve(
      Text(String(score)).font(
        .system(
          size: size.width * 0.134,
          weight: .heavy, design: .rounded)
      ).foregroundColor(.white))
    let unit = context.resolve(
      Text("m").font(
        .system(
          size: size.width * 0.049,
          weight: .heavy, design: .rounded)
      ).foregroundColor(.white))
    let digitSize = digit.measure(in: size)
    let unitSize = unit.measure(in: size)
    let gap = size.width * 0.012
    let startX = (size.width - digitSize.width - gap - unitSize.width) / 2
    let y = geometry.scoreCenter.y
    context.draw(digit, at: CGPoint(x: startX, y: y), anchor: .leading)
    context.draw(
      unit,
      at: CGPoint(
        x: startX + digitSize.width + gap,
        y: y + digitSize.height * 0.19), anchor: .leading)
  }

  private func drawFailureFeedback(in context: inout GraphicsContext) {
    guard failureProgress > 0 else { return }
    let pulse = 0.18 + 0.18 * (1 - min(1, failureProgress))
    context.fill(
      Path(CGRect(origin: .zero, size: size)),
      with: .color(color(0xF04E75).opacity(pulse)))
    let radius = size.width * (0.18 + failureProgress * 0.12)
    context.stroke(
      Path(
        ellipseIn: CGRect(
          x: playerPresentation.frame.midX - radius,
          y: playerPresentation.frame.midY - radius,
          width: radius * 2,
          height: radius * 2)),
      with: .color(.white.opacity(0.7 * (1 - failureProgress))),
      lineWidth: max(2, size.width * 0.012))
  }

  private func cloud(in context: inout GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat) {
    let w = size.width * width
    let center = CGPoint(x: size.width * x, y: size.height * y)
    let body = color(0xE6D8BB)
    ellipse(
      in: &context, center: CGPoint(x: center.x - w * 0.23, y: center.y - w * 0.07),
      width: w * 0.42, height: w * 0.22, fill: body)
    ellipse(
      in: &context, center: CGPoint(x: center.x - w * 0.03, y: center.y - w * 0.12),
      width: w * 0.47, height: w * 0.35, fill: body)
    ellipse(
      in: &context, center: CGPoint(x: center.x + w * 0.23, y: center.y - w * 0.045),
      width: w * 0.44, height: w * 0.22, fill: color(0xDDCCAF))
    let base = CGRect(x: center.x - w / 2, y: center.y - w * 0.065, width: w, height: w * 0.16)
    context.fill(
      Path(ellipseIn: base),
      with: .linearGradient(
        Gradient(colors: [color(0xE9D9B3), color(0xAF795F)]),
        startPoint: CGPoint(x: 0, y: base.minY), endPoint: CGPoint(x: 0, y: base.maxY)))
  }

  private func cactus(
    in context: inout GraphicsContext, x: CGFloat, ground: CGFloat, height: CGFloat
  ) {
    let h = size.height * height
    let w = h * 0.14
    let px = size.width * x
    let py = size.height * ground
    let green = color(0x548B3A)
    for rect in [
      CGRect(x: px - w / 2, y: py - h, width: w, height: h),
      CGRect(x: px - w * 1.9, y: py - h * 0.77, width: w * 0.72, height: h * 0.43),
      CGRect(x: px - w * 1.9, y: py - h * 0.43, width: w * 1.6, height: w * 0.7),
      CGRect(x: px + w * 1.1, y: py - h * 0.63, width: w * 0.7, height: h * 0.43),
      CGRect(x: px + w * 0.2, y: py - h * 0.29, width: w * 1.6, height: w * 0.7),
    ] {
      context.fill(Path(roundedRect: rect, cornerRadius: w * 0.12), with: .color(green))
    }
    context.fill(
      Path(CGRect(x: px - w * 0.35, y: py - h * 0.98, width: w * 0.28, height: h * 0.98)),
      with: .color(color(0x72A84C)))
  }

  private func ellipse(
    in context: inout GraphicsContext, center: CGPoint,
    width: CGFloat, height: CGFloat, fill: Color
  ) {
    context.fill(
      Path(
        ellipseIn: CGRect(
          x: center.x - width / 2, y: center.y - height / 2,
          width: width, height: height)), with: .color(fill))
  }

  private func polygon(
    in context: inout GraphicsContext, points: [(CGFloat, CGFloat)], fill: Color
  ) {
    context.fill(
      path(points.map { CGPoint(x: $0.0 * size.width, y: $0.1 * size.height) }),
      with: .color(fill))
  }

  private func unitPolygon(
    in context: inout GraphicsContext, points: [(CGFloat, CGFloat)], hex: UInt32
  ) {
    context.fill(path(points.map { CGPoint(x: $0.0, y: $0.1) }), with: .color(color(hex)))
  }

  private func path(_ points: [CGPoint]) -> Path {
    Path { path in
      guard let first = points.first else { return }
      path.move(to: first)
      for point in points.dropFirst() { path.addLine(to: point) }
      path.closeSubpath()
    }
  }

  private func color(_ hex: UInt32) -> Color {
    Color(
      red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
      blue: Double(hex & 255) / 255)
  }
}
