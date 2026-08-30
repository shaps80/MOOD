import Pixl2D
import Testing
@testable import Pixl

@Suite("Platformer controller")
struct PlatformerControllerTests {
    private let step: Float = 1 / 60

    @Test
    func presetScalesOnlySpatialValues() {
        let unit = PlatformerConfiguration.flexible()
        let scaled = PlatformerConfiguration.flexible(scale: 32)

        #expect(scaled.movement.runSpeed == unit.movement.runSpeed * 32)
        #expect(scaled.jump.maximumHeight == unit.jump.maximumHeight * 32)
        #expect(scaled.jump.timeToApex == unit.jump.timeToApex)
        #expect(scaled.jump.bufferDuration == unit.jump.bufferDuration)
        #expect(scaled.jump.maximumCount == unit.jump.maximumCount)
        #expect(abs(scaled.gravity - (unit.gravity * 32)) < 0.001)
    }

    @Test
    func groundedJumpUsesDerivedVelocity() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.jump.maximumCount = 1
        var controller = PlatformerController(configuration: configuration)
        ground(&controller)
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )

        _ = controller.advance(delta: step)

        #expect(controller.state == .runJumping)
        #expect(controller.velocity.y > 0)
        #expect(controller.velocity.y < configuration.maximumJumpVelocity)
        #expect(!controller.isGrounded)
    }

    @Test
    func releasingJumpClampsItsHeight() {
        var controller = PlatformerController()
        ground(&controller)
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step)

        controller.capture(
            .init(jump: .init(wasReleased: true))
        )
        _ = controller.advance(delta: step)

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

        _ = controller.advance(delta: step)
        #expect(controller.velocity.y < 0)

        ground(&controller)
        _ = controller.advance(delta: step)

        #expect(controller.velocity.y > 0)
        #expect(controller.state == .runJumping)
    }

    @Test
    func coyoteJumpWorksAfterLeavingGround() {
        var configuration = PlatformerConfiguration.flexible()
        configuration.jump.maximumCount = 1
        var controller = PlatformerController(configuration: configuration)
        ground(&controller)
        _ = controller.advance(delta: step)

        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step)

        #expect(controller.velocity.y > 0)
        #expect(controller.state == .runJumping)
    }

    @Test
    func groundJumpPreservesRemainingAirJumpAfterCoyoteExpires() {
        var controller = PlatformerController()
        ground(&controller)
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step)

        controller.capture(
            .init(jump: .init(wasReleased: true))
        )
        _ = controller.advance(delta: step)

        for _ in 0..<12 {
            controller.capture(.init())
            _ = controller.advance(delta: step)
        }

        let velocityBeforeAirJump = controller.velocity.y
        controller.capture(
            .init(jump: .init(isHeld: true, wasPressed: true))
        )
        _ = controller.advance(delta: step)

        #expect(controller.velocity.y > velocityBeforeAirJump)
        #expect(controller.state == .runJumping)
    }

    @Test
    func facingPersistsAfterHorizontalMovementStops() {
        var controller = PlatformerController()
        ground(&controller)
        controller.capture(.init(movement: .init(-1, 0)))
        _ = controller.advance(delta: step)
        #expect(!controller.isFacingRight)

        ground(&controller)
        controller.capture(.init())
        for _ in 0..<20 {
            _ = controller.advance(delta: step)
            ground(&controller)
        }

        #expect(controller.velocity.x == 0)
        #expect(!controller.isFacingRight)
    }

    @Test
    func wallContactRemovesVelocityIntoWall() {
        var controller = PlatformerController()
        controller.capture(.init(movement: .init(1, 0)))
        _ = controller.advance(delta: step)
        #expect(controller.velocity.x > 0)

        _ = controller.resolve(.init(normal: .init(1, 0), depth: 1))

        #expect(controller.velocity.x == 0)
        #expect(controller.isTouchingWall)
    }

    private func ground(_ controller: inout PlatformerController) {
        _ = controller.resolve(.init(normal: .init(0, -1), depth: 0.01))
    }
}
