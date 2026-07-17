import Testing
@testable import PixlPlatform

@Suite("Keyboard")
struct KeyboardTests {
    @Test
    func publishesTransitionsAndMaintainsCurrentState() {
        let keyboard = Keyboard()

        keyboard.handle(.init(key: .d, phase: .down))
        #expect(keyboard.contains(.d))
        #expect(!keyboard.contains(.d, phase: .down))

        keyboard.publishPendingEvents()
        #expect(keyboard.contains(.d))
        #expect(keyboard.contains(.d, phase: .down))
        #expect(keyboard.key(.d, phase: .down)?.isRepeat == false)

        keyboard.publishPendingEvents()
        #expect(keyboard.contains(.d))
        #expect(!keyboard.contains(.d, phase: .down))

        keyboard.handle(.init(key: .d, phase: .up))
        keyboard.publishPendingEvents()
        #expect(!keyboard.contains(.d))
        #expect(keyboard.contains(.d, phase: .up))
    }

    @Test
    func coalescesRepeatedDownEventsPerFrame() {
        let keyboard = Keyboard()
        keyboard.handle(.init(key: .a, phase: .down))
        keyboard.publishPendingEvents()

        keyboard.handle(.init(key: .a, phase: .down, isRepeat: true))
        keyboard.handle(.init(key: .a, phase: .down, isRepeat: true))
        keyboard.publishPendingEvents()

        #expect(keyboard.events.count == 1)
        #expect(keyboard.key(.a, phase: .down)?.isRepeat == true)
    }

    @Test
    func focusLossReleasesEveryDownKey() {
        let keyboard = Keyboard()
        keyboard.focus(true)
        keyboard.handle(.init(key: .leftShift, phase: .down, modifiers: .shift))
        keyboard.handle(.init(key: .w, phase: .down, modifiers: .shift))

        keyboard.focus(false)
        keyboard.publishPendingEvents()

        #expect(!keyboard.isFocused)
        #expect(!keyboard.contains(.leftShift))
        #expect(!keyboard.contains(.w))
        #expect(keyboard.contains(.leftShift, phase: .up))
        #expect(keyboard.contains(.w, phase: .up))
    }
}
