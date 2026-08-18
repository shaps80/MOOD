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
                operation: .set,
                value: .constant([1, 2])
            )
        )
        property.append(
            .init(
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

    @Test("Emitter properties infer their value type from key paths")
    func emitterKeyPath() {
        var emitter = Emitter(
            capacity: 10,
            spawnRegion: .point(.zero)
        )

        emitter[\.color].append(.set(.white))
        emitter[\.position].append(.set([1, 2, 3]))

        #expect(emitter[\.color].last?.value == .constant(.white))
        #expect(emitter[\.position].last?.value == .constant([1, 2, 3]))
    }

    @Test("Modifier identity is assigned and retained by its property")
    func identity() throws {
        var property = Property<Vec3>()
        property.append(.set([1, 2, 3]))
        let id = try #require(property.first?.id)

        property[0] = .set([4, 5, 6])

        #expect(property[0].id == id)
        #expect(Property(property).first?.id == id)
    }

    @Test("Random keyframe values retain their variation mode")
    func randomKeyframe() {
        let modifier = Property<Vec2>.Modifier(
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
