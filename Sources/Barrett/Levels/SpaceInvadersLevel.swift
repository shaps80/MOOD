import Pixl

extension World {
    static var spaceInvaders: World {
        var world = World(
            level: Level(
                assets: SceneAssets(sprites: [], sounds: []),
                tilemap: .spaceInvadersBoundary,
                markers: [.init(kind: Player.kind, position: GameConfig.playerStart)]
                    + invaderMarkers
            )
        )

        world.register(Player.self, Bullet.self, Invader.self)
        world.addSystem(InvaderWave(), phase: .update)
        world.camera = .init(
            camera: .init(viewportSize: GameConfig.resolution),
            anchor: .point(
                .init(
                    x: GameConfig.resolution.x / 2,
                    y: GameConfig.resolution.y / 2
                )
            )
        )

        return world
    }

    private static var invaderMarkers: [SpawnMarker] {
        var markers: [SpawnMarker] = []
        let columns = 10
        let rows = 4
        let spacing = Vec2(x: 42, y: 32)
        let origin = Vec2(x: 112, y: 56)

        for row in 0..<rows {
            for column in 0..<columns {
                markers.append(
                    SpawnMarker(
                        kind: Invader.kind,
                        position: Vec2(
                            x: origin.x + (Double(column) * spacing.x),
                            y: origin.y + (Double(row) * spacing.y)
                        )
                    )
                )
            }
        }

        return markers
    }
}

private extension Tilemap {
    static var spaceInvadersBoundary: Tilemap {
        let columns = Int(GameConfig.resolution.x / GameConfig.tileSize.x)
        let rows = Int(GameConfig.resolution.y / GameConfig.tileSize.y)
        var tilemap = Tilemap(
            columns: columns,
            rows: rows,
            tileSize: GameConfig.tileSize,
            fill: .empty
        )
        let wall = Tile(
            kind: .wall,
            material: .shape(Rectangle(), size: GameConfig.tileSize),
            layer: .world,
            tint: .clear,
            collider: Collider(
                bounds: Rect(size: GameConfig.tileSize),
                layer: .world,
                mask: [.player, .bullet],
                behaviour: .blocking
            )
        )

        for column in 0..<columns {
            tilemap[column, 0] = wall
            tilemap[column, rows - 1] = wall
        }

        for row in 0..<rows {
            tilemap[0, row] = wall
            tilemap[columns - 1, row] = wall
        }

        return tilemap
    }
}
