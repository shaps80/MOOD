import Testing
@testable import PixlPlatform

@Suite("Gamepad")
struct GamepadTests {
    @Test
    func publishesButtonTransitionsAndAnalogueValues() {
        let gamepad = Gamepad(index: 0, name: "Test")

        gamepad.update(.leftTrigger, value: 0.75, pressed: true)
        #expect(gamepad.contains(.leftTrigger))
        #expect(gamepad.value(for: .leftTrigger) == 0.75)

        gamepad.publishPendingEvents()
        #expect(gamepad.contains(.leftTrigger, phase: .down))
        #expect(gamepad.button(.leftTrigger, phase: .down)?.value == 0.75)

        gamepad.update(.leftTrigger, value: 0.25, pressed: true)
        gamepad.publishPendingEvents()
        #expect(gamepad.events.isEmpty)
        #expect(gamepad.value(for: .leftTrigger) == 0.25)

        gamepad.update(.leftTrigger, value: 0, pressed: false)
        gamepad.publishPendingEvents()
        #expect(gamepad.contains(.leftTrigger, phase: .up))
        #expect(!gamepad.contains(.leftTrigger))
    }

    @Test
    func coalescesEachButtonPhasePerFrame() {
        let gamepad = Gamepad(index: 0, name: "Test")

        gamepad.update(.south, value: 1, pressed: true)
        gamepad.update(.south, value: 0, pressed: false)
        gamepad.update(.south, value: 1, pressed: true)
        gamepad.publishPendingEvents()

        #expect(gamepad.events.count == 2)
        #expect(gamepad.contains(.south))
        #expect(gamepad.contains(.south, phase: .down))
        #expect(gamepad.contains(.south, phase: .up))
    }

    @Test
    func growsAndTracksStablePlayerSlots() throws {
        let gamepads = Gamepads()
        let first = try #require(gamepads.gamepad(at: 0, name: "First"))
        _ = gamepads.gamepad(at: 7, name: "Eighth")

        #expect(gamepads.map(\.index) == [0, 7])

        gamepads.disconnect(at: 0)
        #expect(!first.isConnected)
        #expect(gamepads.map(\.index) == [7])

        let reconnected = try #require(
            gamepads.gamepad(at: 0, name: "Replacement")
        )
        #expect(reconnected === first)
        #expect(reconnected.isConnected)
        #expect(reconnected.name == "Replacement")
    }

    @Test
    func disconnectReleasesButtonsAndSticks() {
        let gamepad = Gamepad(index: 0, name: "Test")
        gamepad.update(.east, value: 1, pressed: true)
        gamepad.updateSticks(left: .init(0.5, -0.5), right: .init(-1, 1))

        gamepad.disconnect()

        #expect(!gamepad.isConnected)
        #expect(!gamepad.contains(.east))
        #expect(gamepad.leftStick == .zero)
        #expect(gamepad.rightStick == .zero)
    }
}
