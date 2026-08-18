import PixlMath
import PixlRenderer
import Swift

public struct Camera: Sendable {
    public var position: SIMD3<Float>
    public var orientation: Quat
    public var projection: Projection

    public init(
        position: SIMD3<Float>,
        orientation: Quat,
        projection: Projection
    ) {
        self.position = position
        self.orientation = normalize(orientation)
        self.projection = projection
    }

    public func viewport(for size: SIMD2<Float>) -> Viewport? {
        guard size.x > 0, size.y > 0 else { return nil }
        let projection = projection.matrices(aspectRatio: size.x / size.y)
        let basis = basis
        return Viewport(
            viewProjection: projection.projection * viewMatrix(basis: basis),
            inverseViewProjection: inverseViewMatrix(basis: basis)
                * projection.inverse,
            cameraPosition: position,
            cameraRight: basis.right,
            cameraUp: basis.up,
            size: size
        )
    }

    private var basis: (
        right: SIMD3<Float>,
        up: SIMD3<Float>,
        backward: SIMD3<Float>
    ) {
        (
            act(orientation, [1, 0, 0]),
            act(orientation, [0, 1, 0]),
            act(orientation, [0, 0, 1])
        )
    }

    private func viewMatrix(
        basis: (
            right: SIMD3<Float>,
            up: SIMD3<Float>,
            backward: SIMD3<Float>
        )
    ) -> Matrix4x4 {
        return Matrix4x4(
            x: [basis.right.x, basis.up.x, basis.backward.x, 0],
            y: [basis.right.y, basis.up.y, basis.backward.y, 0],
            z: [basis.right.z, basis.up.z, basis.backward.z, 0],
            w: [
                -dot(basis.right, position),
                -dot(basis.up, position),
                -dot(basis.backward, position),
                1,
            ]
        )
    }

    private func inverseViewMatrix(
        basis: (
            right: SIMD3<Float>,
            up: SIMD3<Float>,
            backward: SIMD3<Float>
        )
    ) -> Matrix4x4 {
        return Matrix4x4(
            x: SIMD4<Float>(basis.right, 0),
            y: SIMD4<Float>(basis.up, 0),
            z: SIMD4<Float>(basis.backward, 0),
            w: SIMD4<Float>(position, 1)
        )
    }
}

public extension Camera {
    struct Viewport: Sendable {
        public let viewProjection: Matrix4x4
        public let inverseViewProjection: Matrix4x4
        public let cameraPosition: SIMD3<Float>
        public let cameraRight: SIMD3<Float>
        public let cameraUp: SIMD3<Float>
        public let size: SIMD2<Float>

        public var frustumCorners: [SIMD3<Float>] {
            [Float(0), 1].flatMap { depth in
                [
                    SIMD2<Float>(-1, -1),
                    SIMD2<Float>(1, -1),
                    SIMD2<Float>(1, 1),
                    SIMD2<Float>(-1, 1),
                ].map { point in
                    let world = inverseViewProjection
                        * SIMD4<Float>(point.x, point.y, depth, 1)
                    return SIMD3<Float>(world.x, world.y, world.z) / world.w
                }
            }
        }

        public func project(_ position: SIMD3<Float>) -> SIMD2<Float>? {
            let clip = viewProjection * SIMD4<Float>(position, 1)
            guard clip.w > 0, clip.z >= 0, clip.z <= clip.w else { return nil }
            return screenPosition(for: clip)
        }

        private func screenPosition(for clip: SIMD4<Float>) -> SIMD2<Float> {
            let normalized = SIMD2<Float>(clip.x, clip.y) / clip.w
            return [
                size.x * (normalized.x + 1) / 2,
                size.y * (1 - normalized.y) / 2,
            ]
        }
    }
}
