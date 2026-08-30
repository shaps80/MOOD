import Pixl2D

/// Tunable movement behavior for ``PlatformerController``.
public struct PlatformerConfiguration: Equatable, Sendable {
    public enum DefaultMovementMode: Equatable, Sendable {
        case walk
        case run
    }

    public struct Movement: Equatable, Sendable {
        public var defaultMode: DefaultMovementMode
        public var walkSpeed: Float
        public var walkAcceleration: Float
        public var walkDeceleration: Float
        public var walkAirAcceleration: Float
        public var walkAirDeceleration: Float
        public var runSpeed: Float
        public var runAcceleration: Float
        public var runDeceleration: Float
        public var runAirAcceleration: Float
        public var runAirDeceleration: Float
    }

    public struct Jump: Equatable, Sendable {
        public var maximumHeight: Float
        public var minimumHeight: Float
        public var timeToApex: Float
        public var heightCompensation: Float
        public var risingGravityMultiplier: Float
        public var fallingGravityMultiplier: Float
        public var apexVelocityThreshold: Float
        public var apexGravityMultiplier: Float
        public var maximumCount: Int
        public var bufferDuration: Float
        public var coyoteDuration: Float
    }

    public struct Fall: Equatable, Sendable {
        public var maximumSpeed: Float
        public var maximumUpwardSpeed: Float
        public var groundingVelocity: Float
    }

    public struct Dash: Equatable, Sendable {
        public var speed: Float
        public var maximumAirCount: Int
        public var duration: Float
        public var fallSpeed: Float
        public var fallAcceleration: Float
        public var fallDeceleration: Float
    }

    public struct Wall: Equatable, Sendable {
        public var resetsJumps: Bool
        public var resetsDashes: Bool
        public var slideInitialSpeed: Float
        public var slideMaximumSpeed: Float
        public var slideDeceleration: Float
        public var detachDuration: Float
        public var jumpDuration: Float
        public var jumpClimb: Vec2
        public var jumpOff: Vec2
        public var leap: Vec2
        public var fallSpeed: Float
        public var fallAcceleration: Float
        public var fallDeceleration: Float
    }

    public struct Crouch: Equatable, Sendable {
        public var speed: Float
        public var acceleration: Float
        public var deceleration: Float
        /// Complete local-space height of the crouching body capsule.
        public var height: Float
        public var centerOffset: Float
        public var rollSpeed: Float
        public var rollDuration: Float
    }

    public struct Collision: Equatable, Sendable {
        /// Standing body geometry in the controlled entity's local space.
        public var standingBody: Capsule2D
        /// Crouching body geometry in the controlled entity's local space.
        public var crouchingBody: Capsule2D
        /// Ground-sensing bounds in the controlled entity's local space.
        public var feet: Rect
        /// Layers treated as solid platformer surfaces by probes and sweeps.
        public var surfaceMask: CollisionMask
        /// Minimum upward component that classifies a surface as walkable.
        public var minimumGroundNormalY: Float
        /// Distance beneath the feet used by the game's ground sensor.
        public var groundProbeDistance: Float
        public var headProbeDistance: Float
        public var wallProbeDistance: Float
        public var wallProbeHeightScale: Float

        /// Returns the local-space body geometry for `stance`.
        public func body(for stance: PlatformerStance) -> Capsule2D {
            switch stance {
            case .standing: standingBody
            case .crouching: crouchingBody
            }
        }
    }

    public var movement: Movement
    public var jump: Jump
    public var fall: Fall
    public var dash: Dash
    public var wall: Wall
    public var crouch: Crouch
    public var collision: Collision

    /// Creates the reference controller preset converted into Pixl world units.
    ///
    /// `scale` converts the preset's normalized spatial values into Pixl world
    /// units. Time values, multipliers, and counts are unaffected.
    public init(scale: Float = 1) {
        precondition(scale.isFinite && scale > 0, "Platformer scale must be positive and finite")

        movement = .init(
            defaultMode: .run,
            walkSpeed: 3 * scale,
            walkAcceleration: 150 * scale,
            walkDeceleration: 150 * scale,
            walkAirAcceleration: 100 * scale,
            walkAirDeceleration: 5 * scale,
            runSpeed: 15 * scale,
            runAcceleration: 150 * scale,
            runDeceleration: 150 * scale,
            runAirAcceleration: 150 * scale,
            runAirDeceleration: 23 * scale
        )
        jump = .init(
            maximumHeight: 3.5 * scale,
            minimumHeight: 1 * scale,
            timeToApex: 0.3,
            heightCompensation: 1.06,
            risingGravityMultiplier: 1,
            fallingGravityMultiplier: 1.2,
            apexVelocityThreshold: 1 * scale,
            apexGravityMultiplier: 0.5,
            maximumCount: 2,
            bufferDuration: 0.2,
            coyoteDuration: 0.13
        )
        fall = .init(
            maximumSpeed: 30 * scale,
            maximumUpwardSpeed: 50 * scale,
            groundingVelocity: -1.5 * scale
        )
        dash = .init(
            speed: 30 * scale,
            maximumAirCount: 2,
            duration: 0.11,
            fallSpeed: 15 * scale,
            fallAcceleration: 80 * scale,
            fallDeceleration: 80 * scale
        )
        wall = .init(
            resetsJumps: true,
            resetsDashes: true,
            slideInitialSpeed: 2.5 * scale,
            slideMaximumSpeed: 3.5 * scale,
            slideDeceleration: 5,
            detachDuration: 0.2,
            jumpDuration: 0.05,
            jumpClimb: .init(20, 25) * scale,
            jumpOff: .init(5, 8) * scale,
            leap: .init(40, 15) * scale,
            fallSpeed: 10 * scale,
            fallAcceleration: 150 * scale,
            fallDeceleration: 23 * scale
        )
        crouch = .init(
            speed: 5 * scale,
            acceleration: 150 * scale,
            deceleration: 150 * scale,
            height: 0.6 * scale,
            centerOffset: 0.2 * scale,
            rollSpeed: 10 * scale,
            rollDuration: 0.25
        )
        let bodyCenter = Vec2(
            0.002660205 * 0.6 * scale,
            0.06919146 * scale
        )
        let bodyWidth = 0.9884307 * 0.6 * scale
        let standingBody = Capsule2D(
            center: bodyCenter,
            size: .init(bodyWidth, 1.079322 * scale)
        )
        let feetHeight = 0.13807607 * scale
        collision = .init(
            standingBody: standingBody,
            crouchingBody: .init(
                center: .init(bodyCenter.x, -crouch.centerOffset),
                size: .init(bodyWidth, crouch.height)
            ),
            feet: .init(
                center: .init(
                    -0.00199249 * 0.6 * scale,
                    standingBody.bounds.minY + (feetHeight * 0.5)
                ),
                size: .init(
                    0.9086599 * 0.6 * scale,
                    feetHeight
                )
            ),
            surfaceMask: .all,
            minimumGroundNormalY: 0.7,
            groundProbeDistance: 0.02 * scale,
            headProbeDistance: 0.02 * scale,
            wallProbeDistance: 0.015 * scale,
            wallProbeHeightScale: 0.9
        )
    }

    /// Named construction for the controller whose defaults inspired this port.
    public static func flexible(scale: Float = 1) -> Self {
        .init(scale: scale)
    }

    var gravity: Float {
        let height = jump.maximumHeight * jump.heightCompensation
        return 2 * height / (jump.timeToApex * jump.timeToApex)
    }

    var maximumJumpVelocity: Float {
        gravity * jump.timeToApex
    }

    var minimumJumpVelocity: Float {
        (2 * jump.minimumHeight * gravity).squareRoot()
    }
}
