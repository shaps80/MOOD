import Testing
@testable import PixlPlatform

@Suite("Mouse")
struct MouseTests {
    @Test
    func publishesRawMotionStateAndSamples() throws {
        let mouse = Mouse()
        mouse.handle(.init(
            timestamp: 1,
            rawLocation: .init(100, 200),
            rawTranslation: .init(3, 4)
        ))
        mouse.handle(.init(
            timestamp: 2,
            rawLocation: .init(110, 220),
            rawTranslation: .init(7, 16)
        ))

        mouse.publishPendingEvents()

        #expect(mouse.rawLocation == .init(110, 220))
        #expect(mouse.rawTranslation == .init(10, 20))
        #expect(mouse.samples.count == 2)
        let sample = try #require(mouse.samples.last)
        #expect(sample.rawLocation == .init(110, 220))
        #expect(sample.rawTranslation == .init(7, 16))
    }

    @Test
    func buttonEventsCarryRawLocation() throws {
        let mouse = Mouse()
        mouse.handle(.init(
            timestamp: 1,
            button: .primary,
            phase: .down,
            rawLocation: .init(40, 80)
        ))

        mouse.publishPendingEvents()

        #expect(mouse.isPressed(.primary))
        let event = try #require(mouse.event(.primary, phase: .down))
        #expect(event.rawLocation == .init(40, 80))
    }
}
