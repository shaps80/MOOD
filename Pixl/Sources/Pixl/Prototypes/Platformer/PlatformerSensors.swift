import Pixl2D

struct PlatformerSensors: Equatable, Sendable {
    var isGrounded = false
    var bumpedHead = false
    var wallDirection: Float = 0

    mutating func include(
        surfaceNormal: Vec2,
        minimumGroundNormalY: Float
    ) {
        guard surfaceNormal.isValid else { return }
        let surfaceNormal = surfaceNormal.normalized
        guard surfaceNormal != .zero else { return }

        if surfaceNormal.y >= minimumGroundNormalY {
            isGrounded = true
        } else if surfaceNormal.y <= -minimumGroundNormalY {
            bumpedHead = true
        } else if surfaceNormal.x != 0 {
            wallDirection = surfaceNormal.x < 0 ? 1 : -1
        }
    }
}
