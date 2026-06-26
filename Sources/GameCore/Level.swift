import Swift

struct Level: Equatable, Sendable {
    let tilemap: Tilemap
    let spawnPoint: Vec2

    init(tilemap: Tilemap, spawnPoint: Vec2) {
        self.tilemap = tilemap
        self.spawnPoint = spawnPoint
    }

    var bounds: Rect {
        tilemap.bounds
    }
}

extension Level {
    static func level1(worldSize: Vec2, tileSize: Vec2) -> Level {
        let tilemap = Tilemap.level1(
            worldSize: worldSize,
            tileSize: tileSize
        )
        let boundaryThickness = tilemap.tileSize.x
        let topLeftQuadrantCenter = Vec2(
            x: (boundaryThickness + (worldSize.x / 2)) / 2,
            y: (boundaryThickness + (worldSize.y / 2)) / 2
        )

        return Level(
            tilemap: tilemap,
            spawnPoint: topLeftQuadrantCenter
        )
    }

    static func level2(worldSize: Vec2, tileSize: Vec2) -> Level {
        let tilemap = Tilemap.level2(
            worldSize: worldSize,
            tileSize: tileSize
        )

        return Level(
            tilemap: tilemap,
            spawnPoint: Vec2(
                x: tileSize.x * 4.5,
                y: worldSize.y / 2
            )
        )
    }
}

private extension Tilemap {
    static func wall(
        tileSize: Vec2,
        color: Color,
        layer: Layer = .world,
        isCollidable: Bool = true
    ) -> Tilemap.Tile {
        Tilemap.Tile(
            kind: .wall,
            material: .color(color),
            layer: layer,
            collider: isCollidable ? Collider(
                bounds: Rect(
                    origin: .zero,
                    size: tileSize
                )
            ) : nil
        )
    }

    static func level1(worldSize: Vec2, tileSize: Vec2) -> Tilemap {
        let columns = Int(worldSize.x / tileSize.x)
        let rows = Int(worldSize.y / tileSize.y)
        let wall = Tilemap.wall(tileSize: tileSize, color: .red)

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

    static func level2(worldSize: Vec2, tileSize: Vec2) -> Tilemap {
        let columns = Int(worldSize.x / tileSize.x)
        let rows = Int(worldSize.y / tileSize.y)
        let brick = Tilemap.wall(
            tileSize: tileSize,
            color: Color(red: 0.68, green: 0.24, blue: 0.12, alpha: 1)
        )
        let pipe = Tilemap.wall(
            tileSize: tileSize,
            color: Color(red: 0.08, green: 0.55, blue: 0.22, alpha: 1)
        )
        let foregroundPipe = Tilemap.wall(
            tileSize: tileSize,
            color: Color(red: 0.08, green: 0.55, blue: 0.22, alpha: 1),
            layer: .foreground,
            isCollidable: false
        )
        let block = Tilemap.wall(
            tileSize: tileSize,
            color: Color(red: 0.94, green: 0.72, blue: 0.18, alpha: 1)
        )

        var tilemap = Tilemap(
            columns: columns,
            rows: rows,
            tileSize: tileSize,
            fill: .empty
        )

        tilemap.fillBorder(with: brick)

        let centerY = rows / 2
        let upperLane = rows / 3
        let lowerLane = (rows * 2) / 3

        tilemap.fillRect(x: 8, y: 6, width: 5, height: 2, with: block)
        tilemap.fillRect(x: 8, y: rows - 8, width: 5, height: 2, with: block)

        tilemap.fillRect(x: 17, y: upperLane - 3, width: 3, height: 7, with: foregroundPipe)
        tilemap.fillRect(x: 16, y: upperLane - 4, width: 5, height: 2, with: foregroundPipe)
        tilemap.fillRect(x: 17, y: lowerLane - 3, width: 3, height: 7, with: foregroundPipe)
        tilemap.fillRect(x: 16, y: lowerLane + 2, width: 5, height: 2, with: foregroundPipe)

        tilemap.fillRect(x: 27, y: centerY - 8, width: 2, height: 16, with: brick)
        tilemap.fillRect(x: 29, y: centerY - 8, width: 8, height: 2, with: brick)
        tilemap.fillRect(x: 29, y: centerY + 6, width: 8, height: 2, with: brick)

        tilemap.fillStairs(
            x: 42,
            y: rows - 8,
            steps: 6,
            rising: true,
            with: brick
        )
        tilemap.fillStairs(
            x: 52,
            y: 7,
            steps: 6,
            rising: false,
            with: brick
        )

        tilemap.fillRect(x: 47, y: centerY - 2, width: 2, height: 5, with: pipe)
        tilemap.fillRect(x: 46, y: centerY - 3, width: 4, height: 2, with: pipe)

        for x in stride(from: 57, through: 67, by: 2) {
            tilemap.fillRect(x: x, y: upperLane, width: 1, height: 1, with: block)
        }

        for x in stride(from: 58, through: 68, by: 2) {
            tilemap.fillRect(x: x, y: lowerLane, width: 1, height: 1, with: block)
        }

        tilemap.fillRect(x: columns - 12, y: centerY - 6, width: 2, height: 12, with: brick)
        tilemap.fillRect(x: columns - 11, y: centerY - 6, width: 6, height: 2, with: brick)
        tilemap.fillRect(x: columns - 11, y: centerY + 4, width: 6, height: 2, with: brick)
        tilemap.fillRect(x: columns - 5, y: centerY - 2, width: 2, height: 4, with: pipe)

        return tilemap
    }

    mutating func fillBorder(with tile: Tilemap.Tile) {
        for x in 0..<columns {
            self[x, 0] = tile
            self[x, rows - 1] = tile
        }

        for y in 0..<rows {
            self[0, y] = tile
            self[columns - 1, y] = tile
        }
    }

    mutating func fillRect(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        with tile: Tilemap.Tile
    ) {
        let minX = max(x, 0)
        let minY = max(y, 0)
        let maxX = min(x + width, columns)
        let maxY = min(y + height, rows)

        guard minX < maxX && minY < maxY else {
            return
        }

        for tileY in minY..<maxY {
            for tileX in minX..<maxX {
                self[tileX, tileY] = tile
            }
        }
    }

    mutating func fillStairs(
        x: Int,
        y: Int,
        steps: Int,
        rising: Bool,
        with tile: Tilemap.Tile
    ) {
        for step in 0..<steps {
            let tileY = rising ? y - step : y + step
            fillRect(
                x: x + step,
                y: tileY,
                width: 1,
                height: step + 1,
                with: tile
            )
        }
    }
}
