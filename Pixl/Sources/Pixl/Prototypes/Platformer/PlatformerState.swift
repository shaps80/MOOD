/// Observable movement state produced by ``PlatformerController``.
public enum PlatformerState: Equatable, Sendable {
    case idle
    case walking
    case running
    case crouching
    case crouchWalking
    case jumping
    case runJumping
    case falling
    case runFalling
    case dash
    case dashFalling
    case wallSliding
    case wallJumping
    case wallFalling
    case crouchRolling
}
