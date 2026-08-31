import PixlMemory
import Swift

enum FrameBenchmarks {
    static func run() -> [BenchmarkResult] {
        [
            runScenario(
                name: "Mixed frame (small)",
                actorCount: 10_000,
                renderCount: 10_000,
                churnCount: 100,
                scratchBytes: 64_000
            ),
            runScenario(
                name: "Mixed frame (heavy)",
                actorCount: 100_000,
                renderCount: 100_000,
                churnCount: 1_000,
                scratchBytes: 1_000_000
            )
        ]
    }

    private static func runScenario(
        name: String,
        actorCount: Int,
        renderCount: Int,
        churnCount: Int,
        scratchBytes: Int
    ) -> BenchmarkResult {
        let arena = try! Arena(
            FramePersistent.self,
            layouts: FrameLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(FrameLayout.self)
        let actors = scope.pool(\.actors)
        let renderPositions = scope.buffer(\.renderPositions)
        let scratch = scope.buffer(\.scratch)
        var handles: [DensePool<FrameLayout, FrameActor>.Handle] = []
        handles.reserveCapacity(actorCount)

        for index in 0..<actorCount {
            handles.append(actors.insert(makeActor(index)))
        }

        var frame: UInt32 = 0
        let result = BenchmarkRunner.measure(
            name,
            operation: "frame",
            operationsPerSample: 1,
            prepare: {},
            body: {
                frame &+= 1

                actors.withMutableElements { elements in
                    for index in elements.indices {
                        elements[index].position += elements[index].velocity
                    }
                }

                renderPositions.removeAll()
                actors.withElements { elements in
                    renderPositions.append(count: renderCount) { index in
                        elements[index].position
                    }
                }

                for _ in 0..<churnCount {
                    let handle = handles.removeLast()
                    _ = actors.remove(handle)
                }
                for index in 0..<churnCount {
                    handles.append(actors.insert(makeActor(index + Int(frame))))
                }

                var lookupChecksum: UInt64 = 0
                let lookupCount = min(1_000, handles.count)
                for index in 0..<lookupCount {
                    let actor = actors.value(for: handles[index])
                    lookupChecksum &+= UInt64(actor.health)
                    lookupChecksum &+= UInt64(actor.position.x.bitPattern)
                }

                scratch.removeAll()
                scratch.append(bytes: .bytes(scratchBytes)) { bytes in
                    bytes.initializeMemory(
                        as: UInt8.self,
                        repeating: UInt8(truncatingIfNeeded: frame)
                    )
                }

                return UInt64(actors.count)
                    &+ UInt64(renderPositions.count)
                    &+ scratch.count.rawValue
                    &+ lookupChecksum
            }
        )

        scope.release()
        return result
    }

    private static func makeActor(_ index: Int) -> FrameActor {
        FrameActor(
            position: SIMD2(Float(index), Float(index & 255)),
            velocity: SIMD2(0.25, -0.125),
            health: UInt32(truncatingIfNeeded: index),
            flags: UInt32(truncatingIfNeeded: index & 3)
        )
    }
}
