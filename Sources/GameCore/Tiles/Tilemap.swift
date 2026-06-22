import Swift

public struct Tilemap: Equatable, Sendable {
    public let columns: Int
    public let rows: Int
    public let tileSize: Vec2
    public private(set) var tiles: [Tile]

    public init(columns: Int, rows: Int, tileSize: Vec2, fill: Tile) {
        precondition(
            columns > 0 && rows > 0,
            "Tilemap dimensions must be positive."
        )
        precondition(
            tileSize.x > 0 && tileSize.y > 0,
            "Tilemap tile size must be positive."
        )

        self.columns = columns
        self.rows = rows
        self.tileSize = tileSize
        self.tiles = Array(repeating: fill, count: columns * rows)
    }

    public init(rows: [[Tile]], tileSize: Vec2, fill: Tile) {
        precondition(
            !rows.isEmpty,
            "Tilemap must contain at least one row."
        )
        precondition(
            tileSize.x > 0 && tileSize.y > 0,
            "Tilemap tile size must be positive."
        )

        let columns = rows.reduce(into: 0) { largestCount, row in
            largestCount = max(largestCount, row.count)
        }

        precondition(
            columns > 0,
            "Tilemap must contain at least one tile."
        )

        self.columns = columns
        self.rows = rows.count
        self.tileSize = tileSize
        self.tiles = rows.flatMap { row in
            row + Array(repeating: fill, count: columns - row.count)
        }
    }

    public func tile(x: Int, y: Int) -> Tile? {
        guard x >= 0,
              y >= 0,
              x < columns,
              y < rows
        else {
            return nil
        }

        return tiles[(y * columns) + x]
    }

    public subscript(x: Int, y: Int) -> Tile {
        get {
            precondition(contains(x: x, y: y), "Tile coordinate is outside tilemap.")

            return tiles[index(x: x, y: y)]
        }
        set {
            precondition(contains(x: x, y: y), "Tile coordinate is outside tilemap.")

            tiles[index(x: x, y: y)] = newValue
        }
    }

    private func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < columns && y < rows
    }

    private func index(x: Int, y: Int) -> Int {
        (y * columns) + x
    }
}
