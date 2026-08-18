import Foundation
@testable import PixlParticles
import Testing

@Suite("Authored properties")
struct PropertyTests {
    @Test("Modifiers use standard mutable collection operations")
    func collection() {
        var property = Property<Vec2>()
        property.append(
            .init(
                id: 1,
                operation: .set,
                value: .constant([1, 2])
            )
        )
        property.append(
            .init(
                id: 2,
                operation: .multiply,
                value: .curve([
                    .init(
                        at: 0,
                        value: .constant([1, 1]),
                        interpolation: .easeOut
                    ),
                    .init(
                        at: 1,
                        value: .constant([0.25, 0.25])
                    ),
                ]),
                variesWith: .life
            )
        )
        property.insert(
            .init(
                id: 3,
                operation: .lessOrEqual,
                value: .constant([3, 5])
            ),
            at: 1
        )

        #expect(property.map(\.id) == [1, 3, 2])

        property.swapAt(1, 2)
        property.remove(at: 1)

        #expect(property.map(\.id) == [1, 3])
    }

    @Test("Random keyframe values retain their variation mode")
    func randomKeyframe() {
        let modifier = Property<Vec2>.Modifier(
            id: 42,
            operation: .add,
            value: .curve([
                .init(
                    at: 0,
                    value: .random(
                        from: [0, 0],
                        to: [1, 2],
                        variation: .perValue
                    ),
                    interpolation: .linear
                ),
                .init(
                    at: 1,
                    value: .random(from: [2, 4], to: [4, 8])
                ),
            ]),
            variesWith: .speed(from: 0, to: 20)
        )

        #expect(
            modifier.value == .curve([
                .init(
                    at: 0,
                    value: .random(
                        from: [0, 0],
                        to: [1, 2],
                        variation: .perValue
                    ),
                    interpolation: .linear
                ),
                .init(
                    at: 1,
                    value: .random(
                        from: [2, 4],
                        to: [4, 8],
                        variation: .proportional
                    )
                ),
            ])
        )
    }

    @Test("Authored properties round-trip through document encoding")
    func coding() throws {
        let property = Property<Color>([
            .init(
                id: 1,
                operation: .multiply,
                value: .curve([
                    .init(
                        at: 0,
                        value: .constant(.white),
                        interpolation: .easeInOut
                    ),
                    .init(
                        at: 1,
                        value: .constant(
                            .init(red: 0, green: 0, blue: 0, alpha: 0)
                        )
                    ),
                ]),
                variesWith: .emitterLoop
            ),
        ])

        let encoded = try JSONEncoder().encode(property)
        let decoded = try JSONDecoder().decode(
            Property<Color>.self,
            from: encoded
        )

        #expect(decoded == property)
    }
}
