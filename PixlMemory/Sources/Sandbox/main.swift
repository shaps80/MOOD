import PixlMemory
import Swift

@Layout("Persistent", policy: .eager)
private struct Persistent {
    @Region var gameState: Float

    static func make(_ layout: inout Layout) {
        layout.reserve(\.gameState, count: 16)
    }
}

@Layout("Boss fight")
private struct BossFight {
    @Region(.densePool) var enemies: SIMD2<Float>

    static func make(_ layout: inout Layout) {
        layout.reserve(\.enemies, count: 128)
    }
}

@Layout("Level 1", policy: .eager)
private struct Level1 {
    @Region var positions: SIMD2<Float>
    @Region var velocities: SIMD2<Float>
    @Region(policy: .lazy) var scratch: RawBytes

    static func make(_ layout: inout Layout) {
        layout.reserve(\.positions, count: 1_000)
        layout.reserve(\.velocities, count: 1_000)
        layout.reserve(\.scratch, bytes: .kilobytes(16))
        layout.reserve(BossFight.self)
    }
}

@Layout("Menu")
private struct Menu {
    @Region var vertices: SIMD2<Float>

    static func make(_ layout: inout Layout) {
        layout.reserve(\.vertices, count: 256)
    }
}

@main
private enum Sandbox {
    static func main() throws {
        let arena = try Arena(
            "Sandbox",
            persistent: Persistent.self,
            layouts: Menu.self, Level1.self
        )
        let state = arena.buffer(\.gameState)
        state.append(1)

        let level = arena.acquire(Level1.self)
        let positions = level.buffer(\.positions)
        positions.append(count: 1_000) { index in
            SIMD2(Float(index), 0)
        }

        var isRunning = true
        while isRunning {
            positions.withMutableElements { elements in
                for index in elements.indices {
                    elements[index].y += 1
                }
            }
            print("Sandbox frame · positions: \(positions.count) · [q] quit")
            isRunning = readLine()?.lowercased() != "q"
        }

        level.release()
        arena.reportPeakUsage()
    }
}
