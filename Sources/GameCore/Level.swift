import Swift

struct Level: Equatable, Sendable {
    let tilemap: Tilemap
    let spawnPoint: Vec2

    init(tilemap: Tilemap, spawnPoint: Vec2) {
        self.tilemap = tilemap
        self.spawnPoint = spawnPoint
    }
}

extension Level {
    static func level1(logicalResolution: Vec2, tileSize: Vec2) -> Level {
        let tilemap = Tilemap.level1(
            worldSize: logicalResolution,
            tileSize: tileSize
        )
        let boundaryThickness = tilemap.tileSize.x
        let topLeftQuadrantCenter = Vec2(
            x: (boundaryThickness + (logicalResolution.x / 2)) / 2,
            y: (boundaryThickness + (logicalResolution.y / 2)) / 2
        )

        return Level(
            tilemap: tilemap,
            spawnPoint: topLeftQuadrantCenter
        )
    }
}

private extension Tilemap {
    static func level1(worldSize: Vec2, tileSize: Vec2) -> Tilemap {
        let columns = Int(worldSize.x / tileSize.x)
        let rows = Int(worldSize.y / tileSize.y)
        let wall = Tilemap.Tile(
            kind: .wall,
            material: .color(.red),
            collider: Collider(
                bounds: Rect(
                    origin: .zero,
                    size: tileSize
                )
            )
        )

        var tilemap = Tilemap(
            columns: columns,
            rows: rows,
            tileSize: tileSize,
            fill: .empty
        )

        for x in 0..<columns {
            tilemap[x, 0] = wall
            tilemap[x, rows - 1] = wall
        }

        for y in 0..<rows {
            tilemap[0, y] = wall
            tilemap[columns - 1, y] = wall
        }

        let centerColumn = columns / 2
        let centerRow = rows / 2
        let horizontalLength = columns / 2
        let verticalLength = rows / 2
        let horizontalStart = centerColumn - (horizontalLength / 2)
        let horizontalEnd = horizontalStart + horizontalLength - 1
        let verticalStart = centerRow - (verticalLength / 2)
        let verticalEnd = verticalStart + verticalLength - 1

        for x in horizontalStart...horizontalEnd {
            tilemap[x, centerRow] = wall
        }

        for y in verticalStart...verticalEnd {
            tilemap[centerColumn, y] = wall
        }

        return tilemap
    }
}
