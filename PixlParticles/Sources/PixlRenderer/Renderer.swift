import Swift

@MainActor
package final class Renderer {
    private let backend: any Backend

    package init(backend: any Backend) {
        self.backend = backend
    }

    package func render(
        previous: Span<Vector3Batch>,
        current: Span<Vector3Batch>,
        count: Int,
        positionsChanged: Bool,
        interpolation: Float,
        viewProjection: Matrix4x4
    ) throws {
        try backend.renderPoints(
            count: count,
            positionsChanged: positionsChanged,
            interpolation: interpolation,
            viewProjection: viewProjection
        ) { destination in
            Self.lowerPositionPairs(
                previous: previous,
                current: current,
                count: count,
                into: destination
            )
        }
    }

    @discardableResult
    package nonisolated static func lowerPositionPairs(
        previous: Span<Vector3Batch>,
        current: Span<Vector3Batch>,
        count: Int,
        into destination: UnsafeMutableBufferPointer<PositionPair>
    ) -> Int {
        precondition(previous.count == current.count)
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
