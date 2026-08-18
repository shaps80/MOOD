import PixlMath
import Swift

public struct Orbit: Sendable {
    public var target: SIMD3<Float>
    public var distance: Float
    public var rotation: Quat
    public var projection: Projection

    public init(
        target: SIMD3<Float>,
        distance: Float,
        yaw: Float,
        pitch: Float,
        projection: Projection
    ) {
        let yaw = Quat(angle: yaw, axis: [0, 1, 0])
        let pitch = Quat(angle: -pitch, axis: [1, 0, 0])
        self.target = target
        self.distance = distance
        rotation = normalize(yaw * pitch)
        self.projection = projection
    }

    public func camera(zoom: Float = 1) -> Camera {
        precondition(zoom > 0)
        return Camera(
            position: target + act(rotation, [0, 0, distance / zoom]),
            orientation: rotation,
            projection: projection
        )
    }

    public mutating func rotate(yawBy yaw: Float, pitchBy pitch: Float) {
        let yawRotation = Quat(angle: yaw, axis: [0, 1, 0])
        let yawed = normalize(yawRotation * rotation)
        let right = act(yawed, [1, 0, 0])
        let pitchRotation = Quat(angle: -pitch, axis: right)
        rotation = normalize(pitchRotation * yawed)
    }

    public mutating func pan(
        by translation: SIMD2<Float>,
        viewportHeight: Float,
        zoom: Float
    ) {
        guard viewportHeight > 0 else { return }
        guard case let .perspective(fieldOfView, _, _) = projection else {
            return
        }
        let worldUnitsPerPoint = 2 * distance / zoom
            * tan(fieldOfView / 2) / viewportHeight
        let right = act(rotation, [1, 0, 0])
        let up = act(rotation, [0, 1, 0])
        target += (-right * translation.x + up * translation.y)
            * worldUnitsPerPoint
    }

    public mutating func clampToGroundPlane(
        height: Float,
        extent: Float,
        viewportSize: SIMD2<Float>,
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

    public mutating func clamp(
        points: [SIMD3<Float>],
        viewportSize: SIMD2<Float>,
        zoom: Float
    ) {
        let midpoint = viewportSize / 2
        for _ in 0..<2 {
            guard let viewport = camera(zoom: zoom).viewport(for: viewportSize)
            else { return }
            let projected = points.compactMap(viewport.project)
            guard projected.count == points.count else { return }
            let minimumX = projected.lazy.map(\.x).min()!
            let maximumX = projected.lazy.map(\.x).max()!
            let minimumY = projected.lazy.map(\.y).min()!
            let maximumY = projected.lazy.map(\.y).max()!
            let correction = SIMD2<Float>(
                midpoint.x < minimumX
                    ? midpoint.x - minimumX
                    : midpoint.x > maximumX ? midpoint.x - maximumX : 0,
                midpoint.y < minimumY
                    ? midpoint.y - minimumY
                    : midpoint.y > maximumY ? midpoint.y - maximumY : 0
            )
            guard correction != .zero else { return }
            pan(
                by: correction,
                viewportHeight: viewportSize.y,
                zoom: zoom
            )
        }
    }
}
