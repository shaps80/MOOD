import CoreGraphics
import PixlParticles
import simd

struct Camera {
    var position: Vec3
    var target: Vec3
    var projection: Projection

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
        let backward = simd_normalize(position - target)
        let right = simd_normalize(simd_cross([0, 1, 0], backward))
        let up = simd_cross(backward, right)

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
                clipPosition.x >= -clipPosition.w,
                clipPosition.x <= clipPosition.w,
                clipPosition.y >= -clipPosition.w,
                clipPosition.y <= clipPosition.w,
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
