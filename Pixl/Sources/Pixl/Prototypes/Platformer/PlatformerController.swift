import Pixl2D

/// A deterministic, fixed-step 2D platformer character controller.
///
/// The controller owns movement state but not an entity, collider, collision
/// world, bindings, animation, or rendering. Capture presentation input,
/// advance it once per fixed tick, move the entity by the returned displacement,
/// then pass accepted solid contacts to ``resolve(_:)``.
public struct PlatformerController: Sendable {
    private enum AirMode: Sendable {
        case walk
        case run
        case dash
        case wall
    }

    public var configuration: PlatformerConfiguration

    public private(set) var state: PlatformerState = .idle
    public private(set) var stance: PlatformerStance = .standing
    public private(set) var velocity: Vec2 = .zero
    public private(set) var isGrounded = false
    public private(set) var isTouchingWall = false
    public private(set) var bumpedHead = false
    public private(set) var isFacingRight = true

    private var horizontalVelocity: Float = 0
    private var input = PlatformerInputBuffer()
    private var wasGrounded = false
    private var previousWallDirection: Float = 0
    private var wallDirection: Float = 0
    private var airMode: AirMode = .walk

    private var jumpBuffer = PlatformerTimer()
    private var coyote = PlatformerTimer()
    private var dash = PlatformerTimer()
    private var crouchRoll = PlatformerTimer()
    private var wallDetach = PlatformerTimer()
    private var wallJumpInput = PlatformerTimer()
    private var wallJumpControlLock = PlatformerTimer()

    private var remainingJumps: Int
    private var remainingAirDashes: Int
    private var consumedWalkOffJump = false
    private var dashDirection = Vec2.zero
    private var rollDirection: Float = 1
    private var pendingWallJumpDirection: Float = 0

    public init(configuration: PlatformerConfiguration = .init()) {
        self.configuration = configuration
        remainingJumps = max(0, configuration.jump.maximumCount)
        remainingAirDashes = max(0, configuration.dash.maximumAirCount)
    }

    /// Captures presentation input without advancing simulation.
    ///
    /// Edge transitions remain buffered until the next fixed step, so input is
    /// not lost when a presentation frame contains zero fixed updates.
    public mutating func capture(_ input: PlatformerInput) {
        self.input.capture(input)
    }

    /// Advances movement by one fixed simulation step.
    /// - Returns: Displacement and discrete actions produced by this step.
    public mutating func advance(
        delta: Float,
        surfaces: PlatformerSurfaces
    ) -> PlatformerStep {
        guard delta.isFinite, delta > 0 else {
            return .init(displacement: .zero)
        }

        var events = PlatformerEvents()

        var contacts = PlatformerSensors()
        contacts.include(
            surfaceNormal: surfaces.groundNormal,
            minimumGroundNormalY: configuration.collision.minimumGroundNormalY
        )
        contacts.include(
            surfaceNormal: surfaces.ceilingNormal,
            minimumGroundNormalY: configuration.collision.minimumGroundNormalY
        )
        contacts.include(
            surfaceNormal: surfaces.wallNormal,
            minimumGroundNormalY: configuration.collision.minimumGroundNormalY
        )
        isGrounded = contacts.isGrounded
        isTouchingWall = contacts.wallDirection != 0
        bumpedHead = contacts.bumpedHead

        prepareContacts(contacts)
        updateFacing()

        let jumpPressed = input.jump.takePress()
        let jumpReleased = input.jump.takeRelease()
        let dashPressed = input.dash.takePress()

        if jumpPressed {
            jumpBuffer.start(duration: configuration.jump.bufferDuration)
        }

        if contacts.bumpedHead, velocity.y > 0 {
            velocity.y = 0
        }

        let jumpRequested = jumpPressed || jumpBuffer.isRunning
        if pendingWallJumpDirection != 0 {
            resolvePendingWallJump()
        } else if shouldStartCrouchRoll(dashPressed: dashPressed, contacts: contacts) {
            startCrouchRoll()
        } else if shouldStartWallJump(jumpRequested: jumpRequested, contacts: contacts) {
            requestWallJump()
        } else if shouldStartJump(jumpRequested: jumpRequested, contacts: contacts) {
            startJump(running: shouldRun, events: &events)
        } else if shouldStartDash(dashPressed: dashPressed, contacts: contacts) {
            startDash(grounded: contacts.isGrounded)
        }

        if jumpReleased, velocity.y > configuration.minimumJumpVelocity {
            velocity.y = configuration.minimumJumpVelocity
        }

        applyCurrentState(contacts: contacts, delta: delta)
        advanceTimers(delta: delta, grounded: contacts.isGrounded)
        return .init(
            displacement: velocity * delta,
            events: events
        )
    }

    /// Resolves one accepted solid contact and records its surface classification.
    /// - Returns: World-space position correction for the controlled entity.
    @discardableResult
    public mutating func resolve(_ contact: Contact2D) -> Vec2 {
        let inwardSpeed = velocity.dot(contact.normal)
        if inwardSpeed > 0 {
            velocity -= contact.normal * inwardSpeed
        }

        return -contact.normal * contact.depth
    }

    private mutating func prepareContacts(_ contacts: PlatformerSensors) {
        let grounded = contacts.isGrounded
        let touchingWall = contacts.wallDirection != 0

        if grounded {
            remainingJumps = max(0, configuration.jump.maximumCount)
            remainingAirDashes = max(0, configuration.dash.maximumAirCount)
            coyote.stop()
            wallJumpInput.stop()
            wallJumpControlLock.stop()
            pendingWallJumpDirection = 0
            consumedWalkOffJump = false
        } else if wasGrounded {
            coyote.start(duration: configuration.jump.coyoteDuration)
        }

        if touchingWall, previousWallDirection == 0 {
            if configuration.wall.resetsJumps {
                remainingJumps = max(0, configuration.jump.maximumCount)
            }
            if configuration.wall.resetsDashes {
                remainingAirDashes = max(0, configuration.dash.maximumAirCount)
            }
        }

        wasGrounded = grounded
        previousWallDirection = contacts.wallDirection
        wallDirection = contacts.wallDirection
    }

    private mutating func updateFacing() {
        if input.movement.x > 0 {
            isFacingRight = true
        } else if input.movement.x < 0 {
            isFacingRight = false
        }
    }

    private var shouldRun: Bool {
        switch configuration.movement.defaultMode {
        case .walk: input.run.isHeld
        case .run: !input.run.isHeld
        }
    }

    private func shouldStartCrouchRoll(
        dashPressed: Bool,
        contacts: PlatformerSensors
    ) -> Bool {
        contacts.isGrounded && input.crouch.isHeld && dashPressed
    }

    private func shouldStartWallJump(
        jumpRequested: Bool,
        contacts: PlatformerSensors
    ) -> Bool {
        jumpRequested && !contacts.isGrounded && contacts.wallDirection != 0
    }

    private func shouldStartJump(
        jumpRequested: Bool,
        contacts: PlatformerSensors
    ) -> Bool {
        guard jumpRequested, !contacts.bumpedHead else { return false }
        return contacts.isGrounded || coyote.isRunning || remainingJumps > 0
    }

    private func shouldStartDash(
        dashPressed: Bool,
        contacts: PlatformerSensors
    ) -> Bool {
        guard dashPressed else { return false }
        return contacts.isGrounded || remainingAirDashes > 0
    }

    private mutating func startJump(
        running: Bool,
        events: inout PlatformerEvents
    ) {
        events.insert(.jumped)
        if remainingJumps < max(0, configuration.jump.maximumCount) {
            events.insert(.multiJumped)
        }
        isGrounded = false
        velocity.y = configuration.maximumJumpVelocity
        remainingJumps = max(0, remainingJumps - 1)
        consumedWalkOffJump = true
        jumpBuffer.stop()
        coyote.stop()
        wallJumpInput.stop()
        wallJumpControlLock.stop()
        pendingWallJumpDirection = 0
        stance = .standing
        airMode = running ? .run : .walk
        state = running ? .runJumping : .jumping
    }

    private mutating func startDash(grounded: Bool) {
        dash.start(duration: configuration.dash.duration)
        dashDirection = normalizedDashDirection
        if !grounded {
            remainingAirDashes = max(0, remainingAirDashes - 1)
        }
        stance = .standing
        state = .dash
    }

    private mutating func startCrouchRoll() {
        crouchRoll.start(duration: configuration.crouch.rollDuration)
        rollDirection = isFacingRight ? 1 : -1
        stance = .crouching
        state = .crouchRolling
    }

    private mutating func requestWallJump() {
        pendingWallJumpDirection = wallDirection
        jumpBuffer.stop()
        coyote.stop()

        if normalizedHorizontalInput == 0,
           configuration.wall.jumpDuration > 0 {
            wallJumpInput.start(duration: configuration.wall.jumpDuration)
        } else {
            startWallJump()
        }
    }

    private mutating func resolvePendingWallJump() {
        if normalizedHorizontalInput != 0 || !wallJumpInput.isRunning {
            startWallJump()
        }
    }

    private mutating func startWallJump() {
        let horizontalInput = normalizedHorizontalInput
        let impulse: Vec2
        if horizontalInput == pendingWallJumpDirection {
            impulse = configuration.wall.jumpClimb
        } else if horizontalInput == 0 {
            impulse = configuration.wall.jumpOff
        } else {
            impulse = configuration.wall.leap
        }

        velocity = .init(-pendingWallJumpDirection * impulse.x, impulse.y)
        horizontalVelocity = velocity.x
        jumpBuffer.stop()
        coyote.stop()
        wallJumpInput.stop()
        wallJumpControlLock.start(
            duration: configuration.wall.controlLockDuration
        )
        pendingWallJumpDirection = 0
        stance = .standing
        airMode = .wall
        state = .wallJumping
    }

    private mutating func applyCurrentState(
        contacts: PlatformerSensors,
        delta: Float
    ) {
        if dash.isRunning {
            applyDash()
            return
        }
        if crouchRoll.isRunning, contacts.isGrounded {
            applyCrouchRoll()
            return
        }
        if wallJumpControlLock.isRunning {
            stance = .standing
            applyGravity(delta: delta)
            state = .wallJumping
            return
        }
        if (state == .jumping || state == .runJumping), velocity.y > 0 {
            applyAirMovement(delta: delta)
            return
        }
        if !contacts.isGrounded,
           contacts.wallDirection != 0,
           !wallJumpControlLock.isRunning,
           !wallDetach.isRunning {
            applyWallSlide(delta: delta)
            return
        }
        if contacts.isGrounded {
            applyGroundMovement(delta: delta)
        } else {
            applyAirMovement(delta: delta)
        }
    }

    private mutating func applyGroundMovement(delta: Float) {
        let mustRemainCrouched = stance == .crouching && bumpedHead
        stance = input.crouch.isHeld || mustRemainCrouched
            ? .crouching
            : .standing

        let speed: Float
        let acceleration: Float
        let deceleration: Float
        if stance == .crouching {
            speed = configuration.crouch.speed
            acceleration = configuration.crouch.acceleration
            deceleration = configuration.crouch.deceleration
        } else if shouldRun {
            speed = configuration.movement.runSpeed
            acceleration = configuration.movement.runAcceleration
            deceleration = configuration.movement.runDeceleration
        } else {
            speed = configuration.movement.walkSpeed
            acceleration = configuration.movement.walkAcceleration
            deceleration = configuration.movement.walkDeceleration
        }

        applyHorizontalMovement(
            speed: speed,
            acceleration: acceleration,
            deceleration: deceleration,
            delta: delta
        )
        velocity.y = configuration.fall.groundingVelocity

        if stance == .crouching {
            state = normalizedHorizontalInput == 0 ? .crouching : .crouchWalking
        } else if normalizedHorizontalInput == 0, horizontalVelocity == 0 {
            state = .idle
        } else {
            state = shouldRun ? .running : .walking
        }
    }

    private mutating func applyAirMovement(delta: Float) {
        stance = .standing

        let speed: Float
        let acceleration: Float
        let deceleration: Float
        switch airMode {
        case .walk:
            speed = configuration.movement.walkSpeed
            acceleration = configuration.movement.walkAirAcceleration
            deceleration = configuration.movement.walkAirDeceleration
        case .run:
            speed = configuration.movement.runSpeed
            acceleration = configuration.movement.runAirAcceleration
            deceleration = configuration.movement.runAirDeceleration
        case .dash:
            speed = configuration.dash.fallSpeed
            acceleration = configuration.dash.fallAcceleration
            deceleration = configuration.dash.fallDeceleration
        case .wall:
            speed = configuration.wall.fallSpeed
            acceleration = configuration.wall.fallAcceleration
            deceleration = configuration.wall.fallDeceleration
        }

        applyHorizontalMovement(
            speed: speed,
            acceleration: acceleration,
            deceleration: deceleration,
            delta: delta
        )
        applyGravity(delta: delta)

        if velocity.y > 0 {
            state = airMode == .run ? .runJumping : .jumping
        } else {
            switch airMode {
            case .run: state = .runFalling
            case .dash: state = .dashFalling
            case .wall: state = .wallFalling
            case .walk: state = .falling
            }
        }
    }

    private mutating func applyDash() {
        if input.movement != .zero,
           input.movement.normalized.dot(dashDirection) < -0.99 {
            dash.stop()
            airMode = .dash
            return
        }
        velocity = dashDirection * configuration.dash.speed
        horizontalVelocity = velocity.x
        state = .dash
    }

    private mutating func applyCrouchRoll() {
        horizontalVelocity = rollDirection * configuration.crouch.rollSpeed
        velocity = .init(horizontalVelocity, configuration.fall.groundingVelocity)
        state = .crouchRolling
    }

    private mutating func applyWallSlide(delta: Float) {
        if state != .wallSliding {
            velocity = .init(0, -configuration.wall.slideInitialSpeed)
        }

        let movingAway = normalizedHorizontalInput != 0
            && normalizedHorizontalInput != wallDirection
        if movingAway {
            if !wallDetach.isRunning {
                wallDetach.start(duration: configuration.wall.detachDuration)
            }
        } else {
            wallDetach.stop()
        }

        let target = -configuration.wall.slideMaximumSpeed
        let amount = min(1, configuration.wall.slideDeceleration * delta)
        velocity.y += (target - velocity.y) * amount
        velocity.x = 0
        horizontalVelocity = 0
        state = .wallSliding
    }

    private mutating func applyHorizontalMovement(
        speed: Float,
        acceleration: Float,
        deceleration: Float,
        delta: Float
    ) {
        let target = normalizedHorizontalInput * speed
        let rate = normalizedHorizontalInput == 0 ? deceleration : acceleration
        horizontalVelocity = move(horizontalVelocity, toward: target, by: rate * delta)
        velocity.x = horizontalVelocity
    }

    private mutating func applyGravity(delta: Float) {
        let multiplier: Float
        if abs(velocity.y) < configuration.jump.apexVelocityThreshold {
            multiplier = configuration.jump.apexGravityMultiplier
        } else if velocity.y > 0, input.jump.isHeld {
            multiplier = configuration.jump.risingGravityMultiplier
        } else {
            multiplier = configuration.jump.fallingGravityMultiplier
        }

        velocity.y -= configuration.gravity * multiplier * delta
        velocity.y = min(velocity.y, configuration.fall.maximumUpwardSpeed)
        velocity.y = max(velocity.y, -configuration.fall.maximumSpeed)
    }

    private mutating func advanceTimers(delta: Float, grounded: Bool) {
        _ = jumpBuffer.advance(by: delta)
        let coyoteExpired = coyote.advance(by: delta)
        _ = dash.advance(by: delta)
        _ = crouchRoll.advance(by: delta)
        _ = wallDetach.advance(by: delta)
        _ = wallJumpInput.advance(by: delta)
        _ = wallJumpControlLock.advance(by: delta)

        if coyoteExpired, !grounded, !consumedWalkOffJump {
            remainingJumps = max(0, remainingJumps - 1)
            consumedWalkOffJump = true
        }
        if !dash.isRunning, state == .dash {
            airMode = grounded ? (shouldRun ? .run : .walk) : .dash
        }
    }

    private var normalizedHorizontalInput: Float {
        if input.movement.x > 0 { return 1 }
        if input.movement.x < 0 { return -1 }
        return 0
    }

    private var normalizedDashDirection: Vec2 {
        var direction = Vec2(
            input.movement.x > 0 ? 1 : (input.movement.x < 0 ? -1 : 0),
            input.movement.y > 0 ? 1 : (input.movement.y < 0 ? -1 : 0)
        )
        if direction == .zero {
            direction.x = isFacingRight ? 1 : -1
        }
        return direction.normalized
    }

    private func move(_ value: Float, toward target: Float, by amount: Float) -> Float {
        guard amount > 0 else { return value }
        if value < target { return min(value + amount, target) }
        return max(value - amount, target)
    }
}
