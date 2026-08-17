import CoreGraphics
import PixlParticles
import simd

struct Camera {
    var position: Vec3
    var orientation: simd_quatf
    var projection: Projection

    init(
        position: Vec3,
        orientation: simd_quatf,
        projection: Projection
    ) {
        self.position = position
        self.orientation = simd_normalize(orientation)
        self.projection = projection
    }

    init(
        position: Vec3,
        lookingAt target: Vec3,
        projection: Projection,
        worldUp: Vec3 = [0, 1, 0]
    ) {
        let backward = position - target
        precondition(simd_length_squared(backward) > 0)

        let normalizedBackward = simd_normalize(backward)
        let right = simd_cross(worldUp, normalizedBackward)
        precondition(simd_length_squared(right) > 0)

        let normalizedRight = simd_normalize(right)
        let up = simd_cross(normalizedBackward, normalizedRight)
        let rotation = simd_float3x3(columns: (
            normalizedRight,
            up,
            normalizedBackward
        ))

        self.init(
            position: position,
            orientation: simd_quatf(rotation),
            projection: projection
        )
    }

    /// Creates a camera pose from orbit controls. Yaw and pitch are radians.
    init(
        orbiting target: Vec3,
        distance: Float,
        yaw: Float,
        pitch: Float,
        projection: Projection
    ) {
        precondition(distance > 0)

        let horizontalScale = cos(pitch)
        let offset: Vec3 = [
            sin(yaw) * horizontalScale,
            sin(pitch),
            cos(yaw) * horizontalScale,
        ]

        self.init(
            position: target + offset * distance,
            lookingAt: target,
            projection: projection
        )
    }

    func viewport(for size: CGSize) -> Viewport? {
        guard size.width > 0, size.height > 0 else { return nil }

        let aspectRatio = Float(size.width / size.height)
        let viewProjection = projection.matrix(aspectRatio: aspectRatio)
            * viewMatrix

        return Viewport(
            viewProjection: viewProjection,
            size: size
        )
    }

    private var viewMatrix: simd_float4x4 {
        let right = orientation.act([1, 0, 0])
        let up = orientation.act([0, 1, 0])
        let backward = orientation.act([0, 0, 1])

        return simd_float4x4(columns: (
            [right.x, up.x, backward.x, 0],
            [right.y, up.y, backward.y, 0],
            [right.z, up.z, backward.z, 0],
            [
                -simd_dot(right, position),
                -simd_dot(up, position),
                -simd_dot(backward, position),
                1,
            ]
        ))
    }
}

extension Camera {
    struct Viewport {
        let viewProjection: simd_float4x4
        let size: CGSize

        var frustumCorners: [Vec3] {
            let inverse = simd_inverse(viewProjection)
            return [Float(0), 1].flatMap { depth in
                [
                    SIMD2<Float>(-1, -1),
                    SIMD2<Float>(1, -1),
                    SIMD2<Float>(1, 1),
                    SIMD2<Float>(-1, 1),
                ].map { point in
                    let world = inverse * SIMD4<Float>(
                        point.x,
                        point.y,
                        depth,
                        1
                    )
                    return Vec3(world.x, world.y, world.z) / world.w
                }
            }
        }

        func project(_ position: Vec3) -> CGPoint? {
            let clipPosition = viewProjection
                * SIMD4<Float>(position, 1)

            guard
                clipPosition.w > 0,
                clipPosition.z >= 0,
                clipPosition.z <= clipPosition.w
            else {
                return nil
            }

            return screenPosition(for: clipPosition)
        }

        func projectLine(
            from start: Vec3,
            to end: Vec3
        ) -> (start: CGPoint, end: CGPoint)? {
            var start = viewProjection * SIMD4<Float>(start, 1)
            var end = viewProjection * SIMD4<Float>(end, 1)

            guard
                Self.clip(&start, &end, distances: (start.z, end.z)),
                Self.clip(
                    &start,
                    &end,
                    distances: (start.w - start.z, end.w - end.z)
                )
            else {
                return nil
            }

            return (
                screenPosition(for: start),
                screenPosition(for: end)
            )
        }

        private func screenPosition(
            for clipPosition: SIMD4<Float>
        ) -> CGPoint {
            let x = clipPosition.x / clipPosition.w
            let y = clipPosition.y / clipPosition.w

            return CGPoint(
                x: size.width * Double(x + 1) / 2,
                y: size.height * Double(1 - y) / 2
            )
        }

        private static func clip(
            _ start: inout SIMD4<Float>,
            _ end: inout SIMD4<Float>,
            distances: (start: Float, end: Float)
        ) -> Bool {
            guard distances.start >= 0 || distances.end >= 0 else {
                return false
            }

            guard distances.start < 0 || distances.end < 0 else {
                return true
            }

            let amount = distances.start
                / (distances.start - distances.end)
            let intersection = start + (end - start) * amount

            if distances.start < 0 {
                start = intersection
            } else {
                end = intersection
            }

            return true
        }
    }
}
