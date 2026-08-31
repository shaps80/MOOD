import PixlMemory
import Testing

@Layout("Fixture persistent", policy: .eager)
private struct FixturePersistent {
    @Region var gameData: Float

    static func make(_ layout: inout Layout) {
        layout.reserve(\.gameData, count: 4)
    }
}

@Layout("Fixture level")
private struct FixtureLevel {
    @Region var positions: SIMD2<Float>
    @Region(.densePool) var enemies: UInt32
    @Region(policy: .lazy) var scratch: RawBytes

    static func make(_ layout: inout Layout) {
        layout.reserve(\.positions, count: 16)
        layout.reserve(\.enemies, count: 8)
        layout.reserve(\.scratch, bytes: .kilobytes(1))
    }
}

@Test
private func macroGeneratedKeyPathsCompile() throws {
    let arena = try Arena(
        "Macro fixture",
        persistent: FixturePersistent.self,
        layouts: FixtureLevel.self,
        logging: .disabled
    )
    _ = arena.buffer(\.gameData)

    let level = arena.acquire(FixtureLevel.self)
    _ = level.buffer(\.positions)
    _ = level.pool(\.enemies)
    _ = level.buffer(\.scratch)
    level.release()
}
