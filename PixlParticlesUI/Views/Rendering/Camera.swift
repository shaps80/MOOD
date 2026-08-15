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

            let x = clipPosition.x / clipPosition.w
            let y = clipPosition.y / clipPosition.w

            return CGPoint(
                x: size.width * Double(x + 1) / 2,
                y: size.height * Double(1 - y) / 2
            )
        }
    }
}
