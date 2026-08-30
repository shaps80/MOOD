import Pixl2D

struct PlatformerSensors: Equatable, Sendable {
    var isGrounded = false
    var bumpedHead = false
    var wallDirection: Float = 0

    mutating func reset() {
        self = .init()
    }

    mutating func include(
        _ contact: Contact2D,
        minimumGroundNormalY: Float
    ) {
        let surfaceNormal = -contact.normal
        if surfaceNormal.y >= minimumGroundNormalY {
            isGrounded = true
        } else if surfaceNormal.y <= -minimumGroundNormalY {
            bumpedHead = true
        } else if contact.normal.x != 0 {
            wallDirection = contact.normal.x < 0 ? -1 : 1
        }
    }
}
