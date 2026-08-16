import Testing
@testable import PixlRenderer

@Suite("Renderer lowering")
struct RendererTests {
    @Test("Writes previous and current positions into caller storage")
    func positions() {
        let previous = UnsafeMutableBufferPointer<Vector3Batch>.allocate(
            capacity: 2
        )
        let current = UnsafeMutableBufferPointer<Vector3Batch>.allocate(
            capacity: 2
        )
        previous.initialize(repeating: .init(repeating: [1, 2, 3]))
        current.initialize(repeating: .init(repeating: [4, 5, 6]))
        let destination = UnsafeMutableBufferPointer<PositionPair>.allocate(
            capacity: 5
        )
        destination.initialize(
            repeating: PositionPair(
                previous: Position(x: 0, y: 0, z: 0),
                current: Position(x: 0, y: 0, z: 0)
            )
        )
        defer {
            previous.deinitialize()
            previous.deallocate()
            current.deinitialize()
            current.deallocate()
            destination.deinitialize()
            destination.deallocate()
        }

        let count = Renderer.lowerPositionPairs(
            previous: unsafe Span(
                _unsafeElements: UnsafeBufferPointer(previous)
            ),
            current: unsafe Span(
                _unsafeElements: UnsafeBufferPointer(current)
            ),
            count: 5,
            into: destination
        )

        #expect(count == 5)
        for index in 0..<count {
            let pair = destination[index]
            #expect(pair.previous.x == 1)
            #expect(pair.previous.y == 2)
            #expect(pair.previous.z == 3)
            #expect(pair.current.x == 4)
            #expect(pair.current.y == 5)
            #expect(pair.current.z == 6)
        }
    }
}
