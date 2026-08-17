import CoreGraphics
import PixlParticles
import simd

struct Orbit {
    var target: Vec3
    var distance: Float
    var rotation: simd_quatf
    var projection: Projection

    init(
        target: Vec3,
        distance: Float,
        yaw: Float,
        pitch: Float,
        projection: Projection
    ) {
        let yaw = simd_quatf(angle: yaw, axis: [0, 1, 0])
        let pitch = simd_quatf(angle: -pitch, axis: [1, 0, 0])
        self.target = target
        self.distance = distance
        rotation = simd_normalize(yaw * pitch)
        self.projection = projection
    }

    func camera(
        zoom: Float = 1
    ) -> Camera {
        precondition(zoom > 0)

        let position = target + rotation.act([0, 0, distance / zoom])
        return Camera(
            position: position,
            orientation: rotation,
            projection: projection
        )
    }

    mutating func rotate(
        yawBy yawOffset: Float,
        pitchBy pitchOffset: Float
    ) {
        let yaw = simd_quatf(angle: yawOffset, axis: [0, 1, 0])
        let yawed = simd_normalize(yaw * rotation)
        let right = yawed.act([1, 0, 0])
        let pitch = simd_quatf(angle: -pitchOffset, axis: right)
        rotation = simd_normalize(pitch * yawed)
    }

    mutating func pan(
        by translation: SIMD2<Float>,
        viewportHeight: Float,
        zoom: Float
    ) {
        guard viewportHeight > 0 else { return }
        guard case let .perspective(verticalFieldOfView, _, _) = projection else {
            return
        }

        let worldUnitsPerPoint = 2 * distance / zoom
            * tan(verticalFieldOfView / 2) / viewportHeight
        let right = rotation.act([1, 0, 0])
        let up = rotation.act([0, 1, 0])
        target += (-right * translation.x + up * translation.y)
            * worldUnitsPerPoint
    }

    mutating func clampToGroundPlane(
        height: Float,
        extent: Float,
        viewportSize: CGSize,
        zoom: Float
    ) {
        clamp(
            points: [
                [-extent, height, -extent],
                [extent, height, -extent],
                [-extent, height, extent],
                [extent, height, extent],
            ],
            viewportSize: viewportSize,
            zoom: zoom
        )
    }

    mutating func clamp(
        points: [Vec3],
        viewportSize: CGSize,
        zoom: Float
    ) {
        let midpoint = CGPoint(
            x: viewportSize.width / 2,
            y: viewportSize.height / 2
        )

        for _ in 0..<2 {
            guard let viewport = camera(zoom: zoom).viewport(for: viewportSize) else {
                return
            }
            let projected = points.compactMap(viewport.project)
            guard projected.count == points.count else { return }

            let minimumX = projected.map(\.x).min()!
            let maximumX = projected.map(\.x).max()!
            let minimumY = projected.map(\.y).min()!
            let maximumY = projected.map(\.y).max()!
            let correction = SIMD2<Float>(
                Float(midpoint.x < minimumX
                    ? midpoint.x - minimumX
                    : midpoint.x > maximumX ? midpoint.x - maximumX : 0),
                Float(midpoint.y < minimumY
                    ? midpoint.y - minimumY
                    : midpoint.y > maximumY ? midpoint.y - maximumY : 0)
            )
            guard correction != .zero else { return }
            pan(
                by: correction,
                viewportHeight: Float(viewportSize.height),
                zoom: zoom
            )
        }
    }
}
