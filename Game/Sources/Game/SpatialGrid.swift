import Pixl2D

/// Dense, immutable spatial index for the stress-test sprites.
final class SpatialGrid {
    private let origin: Double
    private let cellSize: Double
    private let width: Int
    private let offsets: [Int]
    private let positions: [Vec2]

    init(count: Int, worldSize: Double, cellSize: Double) {
        precondition(count > 0 && worldSize > 0 && cellSize > 0)
        origin = -worldSize / 2
        self.cellSize = cellSize
        width = Int((worldSize / cellSize).rounded(.up))
        let cellCount = width * width

        var generated = [Vec2]()
        generated.reserveCapacity(count)
        var cellIndices = [Int]()
        cellIndices.reserveCapacity(count)
        var counts = [Int](repeating: 0, count: cellCount)

        for _ in 0..<count {
            let position = Vec2(
                Double.random(in: origin...(-origin)),
                Double.random(in: origin...(-origin))
            )
            let index = Self.cellIndex(
                for: position,
                origin: origin,
                cellSize: cellSize,
                width: width
            )
            generated.append(position)
            cellIndices.append(index)
            counts[index] += 1
        }

        var offsets = [Int](repeating: 0, count: cellCount + 1)
        for index in counts.indices {
            offsets[index + 1] = offsets[index] + counts[index]
        }
        var cursors = offsets
        var positions = [Vec2](repeating: .zero, count: count)
        for index in generated.indices {
            let cellIndex = cellIndices[index]
            positions[cursors[cellIndex]] = generated[index]
            cursors[cellIndex] += 1
        }

        self.offsets = offsets
        self.positions = positions
    }

    @discardableResult
    func forEachPosition(
        in bounds: Rect,
        cellPadding: Int = 0,
        _ body: (Vec2) -> Void
    ) -> Int {
        let minimumX = cellCoordinate(bounds.minX) - cellPadding
        let maximumX = cellCoordinate(bounds.maxX) + cellPadding
        let minimumY = cellCoordinate(bounds.minY) - cellPadding
        let maximumY = cellCoordinate(bounds.maxY) + cellPadding
        guard maximumX >= 0, maximumY >= 0,
              minimumX < width, minimumY < width
        else { return 0 }

        let xRange = max(0, minimumX)...min(width - 1, maximumX)
        let yRange = max(0, minimumY)...min(width - 1, maximumY)
        var count = 0
        for y in yRange {
            for x in xRange {
                let cell = y * width + x
                for index in offsets[cell]..<offsets[cell + 1] {
                    body(positions[index])
                    count += 1
                }
            }
        }
        return count
    }

    private func cellCoordinate(_ value: Double) -> Int {
        Int(((value - origin) / cellSize).rounded(.down))
    }

    private static func cellIndex(
        for position: Vec2,
        origin: Double,
        cellSize: Double,
        width: Int
    ) -> Int {
        let x = min(width - 1, Int(((position.x - origin) / cellSize).rounded(.down)))
        let y = min(width - 1, Int(((position.y - origin) / cellSize).rounded(.down)))
        return y * width + x
    }
}
