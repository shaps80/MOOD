import Pixl2D
import Testing
@testable import Pixl

@Suite("Platformer controller")
struct PlatformerControllerTests {
    private let step: Float = 1 / 60
    private let ground = PlatformerSurfaces(
        groundNormal: .init(0, 1)
    )

    @Test
    func presetScalesOnlySpatialValues() {
        let unit = PlatformerConfiguration.flexible()
        let scaled = PlatformerConfiguration.flexible(scale: 32)

        #expect(scaled.movement.runSpeed == unit.movement.runSpeed * 32)
        #expect(scaled.jump.maximumHeight == unit.jump.maximumHeight * 32)
        #expect(scaled.jump.timeToApex == unit.jump.timeToApex)
        #expect(scaled.jump.bufferDuration == unit.jump.bufferDuration)
        #expect(scaled.jump.maximumCount == unit.jump.maximumCount)
        #expect(
            scaled.wall.controlLockDuration
                == unit.wall.controlLockDuration
        )
        #expect(abs(scaled.gravity - (unit.gravity * 32)) < 0.001)
        #expect(
            scaled.collision.standingBody.bounds.size
                == unit.collision.standingBody.bounds.size * 32
        )
        #expect(
            scaled.collision.crouchingBody.bounds.size
                == unit.collision.crouchingBody.bounds.size * 32
        )
    }

    @Test
    func crouchingBodyUsesAbsoluteHeightAndKeepsItsFeetPlanted() {
        let scale: Float = 48 / 1.7
        let configuration = PlatformerConfiguration.flexible(scale: scale)
        let standing = configuration.collision.standingBody.bounds
        let crouching = configuration.collision.crouchingBody.bounds
        let feet = configuration.collision.feet

        #expect(abs(crouching.height - (0.6 * scale)) < 0.001)
        #expect(abs(crouching.minY - standing.minY) < scale * 0.04)
        #expect(crouching.maxY < standing.maxY)
        #expect(abs(feet.minY - standing.minY) < 0.001)
    }

    @Test
    func groundedJumpUsesDerivedVelocity() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.jump.maximumCount = 1
        var controller = PlatformerController(configuration: configuration)
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )

        _ = controller.advance(delta: step, surfaces: ground)

        #expect(controller.state == .runJumping)
        #expect(controller.velocity.y > 0)
        #expect(controller.velocity.y < configuration.maximumJumpVelocity)
        #expect(!controller.isGrounded)
    }

    @Test
    func releasingJumpClampsItsHeight() {
        var controller = PlatformerController()
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step, surfaces: ground)

        controller.capture(
            .init(jump: .init(wasReleased: true))
        )
        _ = controller.advance(delta: step, surfaces: .init())

        #expect(controller.velocity.y <= controller.configuration.minimumJumpVelocity)
    }

    @Test
    func jumpPressBuffersUntilLanding() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.jump.maximumCount = 0
        var controller = PlatformerController(configuration: configuration)
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )

        _ = controller.advance(delta: step, surfaces: .init())
        #expect(controller.velocity.y < 0)

        _ = controller.advance(delta: step, surfaces: ground)

        #expect(controller.velocity.y > 0)
        #expect(controller.state == .runJumping)
    }

    @Test
    func coyoteJumpWorksAfterLeavingGround() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.jump.maximumCount = 1
        var controller = PlatformerController(configuration: configuration)
        _ = controller.advance(delta: step, surfaces: ground)

        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step, surfaces: .init())

        #expect(controller.velocity.y > 0)
        #expect(controller.state == .runJumping)
    }

    @Test
    func groundJumpPreservesRemainingAirJumpAfterCoyoteExpires() {
        var controller = PlatformerController()
        _ = controller.advance(delta: step, surfaces: ground)
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step, surfaces: ground)

        controller.capture(
            .init(jump: .init(wasReleased: true))
        )
        _ = controller.advance(delta: step, surfaces: .init())

        for _ in 0..<12 {
            controller.capture(.init())
            _ = controller.advance(delta: step, surfaces: .init())
        }

        let velocityBeforeAirJump = controller.velocity.y
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step, surfaces: .init())

        #expect(controller.velocity.y > velocityBeforeAirJump)
        #expect(controller.state == .runJumping)
    }

    @Test
    func facingPersistsAfterHorizontalMovementStops() {
        var controller = PlatformerController()
        controller.capture(.init(movement: .init(-1, 0)))
        _ = controller.advance(delta: step, surfaces: ground)
        #expect(!controller.isFacingRight)

        controller.capture(.init())
        for _ in 0..<20 {
            _ = controller.advance(delta: step, surfaces: ground)
        }

        #expect(controller.velocity.x == 0)
        #expect(!controller.isFacingRight)
    }

    @Test
    func wallContactRemovesVelocityIntoWall() {
        var controller = PlatformerController()
        controller.capture(.init(movement: .init(1, 0)))
        _ = controller.advance(delta: step, surfaces: .init())
        #expect(controller.velocity.x > 0)

        _ = controller.resolve(.init(normal: .init(1, 0), depth: 1))

        #expect(controller.velocity.x == 0)
        #expect(!controller.isTouchingWall)
    }

    @Test
    func wallSurfaceKeepsWallSlideStableWithoutPenetration() {
        var controller = PlatformerController()
        let surfaces = PlatformerSurfaces(
            wallNormal: .init(-1, 0)
        )

        for _ in 0..<10 {
            controller.capture(.init(movement: .init(1, 0)))
            _ = controller.advance(delta: step, surfaces: surfaces)
            #expect(controller.state == .wallSliding)
            #expect(controller.isTouchingWall)
        }
    }

    @Test
    func neutralWallJumpWaitsForInputBeforeJumpingOff() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.wall.jumpDuration = step * 2
        var controller = PlatformerController(configuration: configuration)
        let rightWall = PlatformerSurfaces(wallNormal: .init(-1, 0))

        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step, surfaces: rightWall)
        #expect(controller.velocity.y <= 0)

        controller.capture(.init(jump: .init(isHeld: true)))
        _ = controller.advance(delta: step, surfaces: rightWall)
        #expect(controller.velocity.y <= 0)

        _ = controller.advance(delta: step, surfaces: rightWall)
        #expect(controller.velocity.x == -configuration.wall.jumpOff.x)
        #expect(controller.velocity.y > 0)
    }

    @Test
    func wallJumpPreservesHorizontalImpulseDuringControlLock() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.wall.controlLockDuration = step * 4
        var controller = PlatformerController(configuration: configuration)
        let rightWall = PlatformerSurfaces(wallNormal: .init(-1, 0))

        controller.capture(
            .init(
                movement: .init(-1, 0),
                jump: .init(isHeld: true, wasPressed: true)
            )
        )
        _ = controller.advance(delta: step, surfaces: rightWall)
        let launchVelocity = controller.velocity.x
        #expect(launchVelocity == -configuration.wall.leap.x)

        controller.capture(.init(movement: .init(1, 0)))
        _ = controller.advance(delta: step, surfaces: .init())
        _ = controller.advance(delta: step, surfaces: .init())
        #expect(controller.velocity.x == launchVelocity)

        _ = controller.advance(delta: step, surfaces: .init())
        _ = controller.advance(delta: step, surfaces: .init())
        _ = controller.advance(delta: step, surfaces: .init())
        #expect(controller.velocity.x > launchVelocity)
    }

    @Test
    func wallLeapRetainsWallClimbVerticalLaunch() {
        let configuration = PlatformerConfiguration.flexible()
        let rightWall = PlatformerSurfaces(wallNormal: .init(-1, 0))

        var climb = PlatformerController(configuration: configuration)
        climb.capture(
            .init(
                movement: .init(1, 0),
                jump: .init(isHeld: true, wasPressed: true)
            )
        )
        _ = climb.advance(delta: step, surfaces: rightWall)

        var leap = PlatformerController(configuration: configuration)
        leap.capture(
            .init(
                movement: .init(-1, 0),
                jump: .init(isHeld: true, wasPressed: true)
            )
        )
        _ = leap.advance(delta: step, surfaces: rightWall)

        #expect(leap.velocity.y == climb.velocity.y)
        #expect(abs(leap.velocity.x) > abs(climb.velocity.x))
    }

    @Test
    func ceilingKeepsGroundedControllerCrouched() {
        var controller = PlatformerController()
        controller.capture(.init(crouch: .init(isHeld: true)))
        _ = controller.advance(delta: step, surfaces: ground)
        #expect(controller.stance == .crouching)

        controller.capture(.init())
        _ = controller.advance(
            delta: step,
            surfaces: .init(
                groundNormal: .init(0, 1),
                ceilingNormal: .init(0, -1)
            )
        )

        #expect(controller.stance == .crouching)
        #expect(controller.bumpedHead)
    }

    @Test
    func airDashReplacesJumpVelocityWithRequestedDirection() {
        var controller = PlatformerController()
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step, surfaces: ground)
        #expect(controller.velocity.y > 0)

        controller.capture(
            .init(
                movement: .init(0, 1),
                dash: .init(isHeld: true, wasPressed: true)
            )
        )
        _ = controller.advance(delta: step, surfaces: .init())

        #expect(controller.state == .dash)
        #expect(controller.velocity.x == 0)
        #expect(controller.velocity.y == controller.configuration.dash.speed)
    }

    @Test
    func diagonalDashUsesNormalizedRequestedDirection() {
        var controller = PlatformerController()
        controller.capture(
            .init(
                movement: .init(1, 1),
                dash: .init(isHeld: true, wasPressed: true)
            )
        )

        _ = controller.advance(delta: step, surfaces: ground)

        let component = controller.configuration.dash.speed
            / Float(2).squareRoot()
        #expect(abs(controller.velocity.x - component) < 0.0001)
        #expect(abs(controller.velocity.y - component) < 0.0001)
    }

    @Test
    func multiJumpProducesOneStepEvent() {
        var controller = PlatformerController()
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )

        let first = controller.advance(delta: step, surfaces: ground)
        #expect(first.events.contains(.jumped))
        #expect(!first.events.contains(.multiJumped))

        controller.capture(
            .init(jump: .init(wasReleased: true))
        )
        let between = controller.advance(delta: step, surfaces: .init())
        #expect(between.events.isEmpty)

        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        let second = controller.advance(delta: step, surfaces: .init())
        #expect(second.events.contains(.jumped))
        #expect(second.events.contains(.multiJumped))

        controller.capture(.init(jump: .init(isHeld: true)))
        let after = controller.advance(delta: step, surfaces: .init())
        #expect(after.events.isEmpty)
    }

    @Test
    func repeatedRunIntoLowPlatformDoesNotPassThroughOrLoseGrounding() {
        let scale: Float = 48 / 1.7
        let surfaceLayer = CollisionLayer(0)
        var configuration = PlatformerConfiguration.flexible(scale: scale)
        configuration.collision.surfaceMask = CollisionMask(surfaceLayer)
        var controller = PlatformerController(configuration: configuration)
        var probes = PlatformerCollisionProbes()
        let collisions = CollisionWorld2D()
        let floor = Rect(x: -400, y: -200, width: 800, height: 20)
        let platform = Rect(x: 80, y: -160, width: 160, height: 16)
        _ = collisions.insert(
            bounds: floor,
            mode: .static,
            layer: surfaceLayer,
            mask: .none
        )
        _ = collisions.insert(
            bounds: platform,
            mode: .static,
            layer: surfaceLayer,
            mask: .none
        )

        let standing = configuration.collision.standingBody
        var position = Vec2(
            40,
            floor.maxY - standing.bounds.minY
        )
        let collider = collisions.insert(
            standing,
            transform: .init(position),
            mode: .dynamic,
            layer: 1,
            mask: CollisionMask(surfaceLayer)
        )

        for _ in 0..<40 {
            let transform = Transform2D(position)
            let surfaces = probes.update(
                stance: controller.stance,
                transform: transform,
                configuration: configuration.collision,
                in: collisions
            )
            controller.capture(.init(movement: .init(1, 0)))
            position += controller.advance(
                delta: 1 / 50,
                surfaces: surfaces
            ).displacement
            collisions.update(
                collider,
                capsule: configuration.collision.body(for: controller.stance),
                transform: .init(position)
            )
            collisions.advance { collision in
                guard collision.source.collider == collider,
                      let contact = collision.contact
                else { return nil }
                position += controller.resolve(contact)
                return .init(position)
            }

            #expect(controller.isGrounded)
            #expect(controller.state == .running)
        }

        let bodyBounds = standing.bounds.translated(by: position)
        #expect(bodyBounds.maxX <= platform.minX + 0.001)
        #expect(controller.isGrounded)
        #expect(controller.state == .running)
    }

    @Test
    func horizontalDashStopsAtLowPlatformWithoutVerticalMotion() {
        let scale: Float = 48 / 1.7
        let surfaceLayer = CollisionLayer(0)
        var configuration = PlatformerConfiguration.flexible(scale: scale)
        configuration.collision.surfaceMask = CollisionMask(surfaceLayer)
        var controller = PlatformerController(configuration: configuration)
        var probes = PlatformerCollisionProbes()
        let collisions = CollisionWorld2D()
        let floor = Rect(x: -400, y: -200, width: 800, height: 20)
        let platform = Rect(x: 80, y: -160, width: 160, height: 16)
        _ = collisions.insert(
            bounds: floor,
            mode: .static,
            layer: surfaceLayer,
            mask: .none
        )
        _ = collisions.insert(
            bounds: platform,
            mode: .static,
            layer: surfaceLayer,
            mask: .none
        )

        let standing = configuration.collision.standingBody
        var position = Vec2(40, floor.maxY - standing.bounds.minY)
        let initialY = position.y
        let collider = collisions.insert(
            standing,
            transform: .init(position),
            mode: .dynamic,
            layer: 1,
            mask: CollisionMask(surfaceLayer)
        )

        for tick in 0..<8 {
            let transform = Transform2D(position)
            let surfaces = probes.update(
                stance: controller.stance,
                transform: transform,
                configuration: configuration.collision,
                in: collisions
            )
            controller.capture(
                .init(
                    movement: .init(1, 0),
                    dash: .init(
                        isHeld: true,
                        wasPressed: tick == 0
                    )
                )
            )
            var displacement = controller.advance(
                delta: 1 / 50,
                surfaces: surfaces
            ).displacement
            if controller.state == .dash
                || abs(controller.velocity.x)
                    > controller.configuration.movement.runSpeed
            {
                displacement = probes.constrainDash(
                    displacement,
                    stance: controller.stance,
                    transform: transform,
                    configuration: configuration.collision,
                    in: collisions
                )
            }
            position += displacement
            collisions.update(
                collider,
                capsule: configuration.collision.body(for: controller.stance),
                transform: .init(position)
            )
            collisions.advance { collision in
                guard collision.source.collider == collider,
                      let contact = collision.contact
                else { return nil }
                position += controller.resolve(contact)
                return .init(position)
            }
        }

        let bodyBounds = standing.bounds.translated(by: position)
        #expect(bodyBounds.maxX <= platform.minX + 0.001)
        #expect(abs(position.y - initialY) < 0.001)
        #expect(controller.velocity.y <= 0)
    }

    @Test
    func crouchingRemainsGroundedAndPassesUnderLowPlatform() {
        let scale: Float = 48 / 1.7
        let surfaceLayer = CollisionLayer(0)
        var configuration = PlatformerConfiguration.flexible(scale: scale)
        configuration.collision.surfaceMask = CollisionMask(surfaceLayer)
        var controller = PlatformerController(configuration: configuration)
        var probes = PlatformerCollisionProbes()
        let collisions = CollisionWorld2D()
        let floor = Rect(x: -400, y: -200, width: 800, height: 20)
        let platform = Rect(x: 80, y: -160, width: 160, height: 16)
        _ = collisions.insert(
            bounds: floor,
            mode: .static,
            layer: surfaceLayer,
            mask: .none
        )
        _ = collisions.insert(
            bounds: platform,
            mode: .static,
            layer: surfaceLayer,
            mask: .none
        )

        let standing = configuration.collision.standingBody
        var position = Vec2(40, floor.maxY - standing.bounds.minY)
        let collider = collisions.insert(
            standing,
            transform: .init(position),
            mode: .dynamic,
            layer: 1,
            mask: CollisionMask(surfaceLayer)
        )

        for _ in 0..<120 {
            let transform = Transform2D(position)
            let surfaces = probes.update(
                stance: controller.stance,
                transform: transform,
                configuration: configuration.collision,
                in: collisions
            )
            controller.capture(
                .init(
                    movement: .init(1, -1),
                    crouch: .init(isHeld: true)
                )
            )
            position += controller.advance(
                delta: 1 / 50,
                surfaces: surfaces
            ).displacement
            collisions.update(
                collider,
                capsule: configuration.collision.body(for: controller.stance),
                transform: .init(position)
            )
            collisions.advance { collision in
                guard collision.source.collider == collider,
                      let contact = collision.contact
                else { return nil }
                position += controller.resolve(contact)
                return .init(position)
            }

            #expect(controller.isGrounded)
            #expect(controller.stance == .crouching)
            #expect(
                controller.state == .crouchWalking
                    || controller.state == .crouchRolling
            )
        }

        #expect(position.x > platform.maxX)
    }

}
