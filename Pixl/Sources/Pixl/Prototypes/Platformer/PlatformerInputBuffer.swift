import Pixl2D

struct PlatformerBufferedButton: Equatable, Sendable {
    private(set) var isHeld = false
    private var pressed = false
    private var released = false
    private var capturedPress = false
    private var capturedRelease = false

    mutating func capture(_ input: PlatformerButtonInput) {
        isHeld = input.isHeld

        if input.wasPressed {
            if !capturedPress {
                pressed = true
                capturedPress = true
            }
        } else {
            capturedPress = false
        }

        if input.wasReleased {
            if !capturedRelease {
                released = true
                capturedRelease = true
            }
        } else {
            capturedRelease = false
        }
    }

    mutating func takePress() -> Bool {
        defer { pressed = false }
        return pressed
    }

    mutating func takeRelease() -> Bool {
        defer { released = false }
        return released
    }
}

struct PlatformerInputBuffer: Equatable, Sendable {
    private(set) var movement = Vec2.zero
    var jump = PlatformerBufferedButton()
    var run = PlatformerBufferedButton()
    var dash = PlatformerBufferedButton()
    var crouch = PlatformerBufferedButton()

    mutating func capture(_ input: PlatformerInput) {
        movement = input.movement.isValid ? input.movement : .zero
        jump.capture(input.jump)
        run.capture(input.run)
        dash.capture(input.dash)
        crouch.capture(input.crouch)
    }
}
