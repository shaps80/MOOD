import PixlParticles
import Swift

package struct Renderer {
    package init() {}

    @discardableResult
    package func lowerPositionPairs(
        from system: System,
        into destination: UnsafeMutableBufferPointer<PositionPair>
    ) -> Int {
        return system.withPositions { previous, current, count in
            precondition(destination.count >= count)

            for batchIndex in previous.indices {
                let previous = previous[batchIndex]
                let current = current[batchIndex]
                let start = batchIndex * 4
                let end = min(4, count - start)

                for lane in 0..<end {
                    destination[start + lane] = PositionPair(
                        previous: Position(
                            x: previous.x[lane],
                            y: previous.y[lane],
                            z: previous.z[lane]
                        ),
                        current: Position(
                            x: current.x[lane],
                            y: current.y[lane],
                            z: current.z[lane]
                        )
                    )
                }
            }

            return count
        }
    }
}
