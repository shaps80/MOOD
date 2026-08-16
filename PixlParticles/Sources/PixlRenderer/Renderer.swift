import PixlParticles
import Swift

package struct Renderer {
    package init() {}

    @discardableResult
    package func lowerPositions(
        from system: System,
        interpolation: Float,
        into destination: UnsafeMutableBufferPointer<Position>
    ) -> Int {
        precondition(interpolation >= 0 && interpolation <= 1)

        return system.withPositions { previous, current, count in
            precondition(destination.count >= count)

            for batchIndex in previous.indices {
                let previous = previous[batchIndex]
                let current = current[batchIndex]
                let x = previous.x
                    + (current.x - previous.x) * interpolation
                let y = previous.y
                    + (current.y - previous.y) * interpolation
                let z = previous.z
                    + (current.z - previous.z) * interpolation
                let start = batchIndex * 4
                let end = min(4, count - start)

                for lane in 0..<end {
                    destination[start + lane] = Position(
                        x: x[lane],
                        y: y[lane],
                        z: z[lane]
                    )
                }
            }

            return count
        }
    }
}
