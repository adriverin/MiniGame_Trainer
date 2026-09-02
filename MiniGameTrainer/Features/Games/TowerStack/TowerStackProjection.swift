import CoreGraphics
import Foundation

/// Camera orientation derived from the config. Shared by the logic (which needs to know which end
/// of an axis is "far" from the camera) and by the renderer.
struct TowerStackCameraRig: Equatable {
    /// Unit vector from the framed point toward the camera.
    let offsetDirection: TowerStackWorldPoint
    let forward: TowerStackWorldPoint
    let right: TowerStackWorldPoint
    let up: TowerStackWorldPoint

    init(config: TowerStackGameConfig) {
        let pitch = config.cameraPitchDegrees * .pi / 180
        let azimuth = config.cameraAzimuthDegrees * .pi / 180
        offsetDirection = TowerStackWorldPoint(
            x: cos(pitch) * sin(azimuth),
            y: sin(pitch),
            z: cos(pitch) * cos(azimuth)
        )
        forward = (offsetDirection * -1).normalized
        right = forward.cross(TowerStackWorldPoint(x: 0, y: 1, z: 0)).normalized
        up = right.cross(forward).normalized
    }

    /// Sign of the axis end that is farthest from the camera (where blocks spawn).
    func farSign(along axis: TowerStackAxis) -> CGFloat {
        let component = axis == .x ? offsetDirection.x : offsetDirection.z
        return component >= 0 ? -1 : 1
    }

    /// Sign of the axis end facing the camera (whose side face is visible).
    func nearSign(along axis: TowerStackAxis) -> CGFloat {
        -farSign(along: axis)
    }
}

/// Visible faces of a block after projection, in scene (SpriteKit, y-up) coordinates.
struct TowerStackProjectedBlock: Equatable {
    /// Top face corners in order: far, screen-left, near, screen-right (a rotated quad).
    let top: [CGPoint]
    /// Side face on the −/+X end that faces the camera.
    let sideX: [CGPoint]
    /// Side face on the −/+Z end that faces the camera.
    let sideZ: [CGPoint]
    /// Screen position of the top face centre.
    let topCenter: CGPoint

    /// True when `sideX` is drawn left of `sideZ` on screen (decides which face gets the dark shade).
    var sideXIsLeft: Bool {
        average(sideX).x <= average(sideZ).x
    }

    private func average(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}

/// Pinhole camera that maps world points (block widths) to scene points. The camera is positioned
/// `config.cameraDistance` away from `target` along `rig.offsetDirection`, so moving the target
/// upward with the tower keeps the framing identical.
struct TowerStackProjection: Equatable {
    let sceneSize: CGSize
    let config: TowerStackGameConfig
    let rig: TowerStackCameraRig
    /// Scene point where the framed target lands.
    let screenCenter: CGPoint
    /// Focal length in scene points.
    let focalLength: CGFloat

    init(sceneSize: CGSize, config: TowerStackGameConfig) {
        self.sceneSize = sceneSize
        self.config = config
        rig = TowerStackCameraRig(config: config)
        screenCenter = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * (1 - config.activeTopYRatio))

        // Calibrate the focal length so a unit block's top face at the target spans the configured
        // fraction of the scene width.
        let unit = TowerStackFootprint(centerX: 0, centerZ: 0, width: 1, depth: 1)
        let corners = Self.topCorners(of: unit, y: 0)
        let rig = self.rig
        let camera = rig.offsetDirection * config.cameraDistance
        let xs = corners.map { corner -> CGFloat in
            let v = corner - camera
            return v.dot(rig.right) / max(v.dot(rig.forward), 0.001)
        }
        let extent = (xs.max() ?? 1) - (xs.min() ?? 0)
        focalLength = extent > 0 ? config.topFaceWidthRatio * sceneSize.width / extent : sceneSize.width
    }

    /// Scene-space size of a unit world length at the framed target depth (approximate scale).
    var unitScale: CGFloat { focalLength / config.cameraDistance }

    func project(_ point: TowerStackWorldPoint, camera target: TowerStackWorldPoint) -> CGPoint {
        let cameraPosition = target + rig.offsetDirection * config.cameraDistance
        let v = point - cameraPosition
        let depth = max(v.dot(rig.forward), 0.05)
        return CGPoint(
            x: screenCenter.x + focalLength * v.dot(rig.right) / depth,
            y: screenCenter.y + focalLength * v.dot(rig.up) / depth
        )
    }

    func projectBlock(
        _ footprint: TowerStackFootprint,
        bottomY: CGFloat,
        topY: CGFloat,
        camera target: TowerStackWorldPoint
    ) -> TowerStackProjectedBlock {
        let top = Self.topCorners(of: footprint, y: topY)
        let bottom = Self.topCorners(of: footprint, y: bottomY)
        let projectedTop = top.map { project($0, camera: target) }
        let projectedBottom = bottom.map { project($0, camera: target) }

        // Corner order from `topCorners`: 0 (minX,minZ) 1 (maxX,minZ) 2 (maxX,maxZ) 3 (minX,maxZ).
        let nearX = rig.nearSign(along: .x)
        let nearZ = rig.nearSign(along: .z)
        let xFace: [Int] = nearX > 0 ? [1, 2] : [0, 3]
        let zFace: [Int] = nearZ > 0 ? [3, 2] : [0, 1]

        func face(_ indices: [Int]) -> [CGPoint] {
            [projectedTop[indices[0]], projectedTop[indices[1]], projectedBottom[indices[1]], projectedBottom[indices[0]]]
        }

        let center = project(TowerStackWorldPoint(x: footprint.centerX, y: topY, z: footprint.centerZ), camera: target)
        return TowerStackProjectedBlock(top: projectedTop, sideX: face(xFace), sideZ: face(zFace), topCenter: center)
    }

    /// Project the four corners of a horizontal rectangle (used for debug footprints).
    func projectFootprintOutline(_ footprint: TowerStackFootprint, y: CGFloat, camera target: TowerStackWorldPoint) -> [CGPoint] {
        Self.topCorners(of: footprint, y: y).map { project($0, camera: target) }
    }

    private static func topCorners(of footprint: TowerStackFootprint, y: CGFloat) -> [TowerStackWorldPoint] {
        [
            TowerStackWorldPoint(x: footprint.minX, y: y, z: footprint.minZ),
            TowerStackWorldPoint(x: footprint.maxX, y: y, z: footprint.minZ),
            TowerStackWorldPoint(x: footprint.maxX, y: y, z: footprint.maxZ),
            TowerStackWorldPoint(x: footprint.minX, y: y, z: footprint.maxZ),
        ]
    }
}
