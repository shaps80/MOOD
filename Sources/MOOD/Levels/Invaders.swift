import Pixl

extension OldLevel {
    static let invaders: Self = {
        let tilemap = Tilemap(
            columns: 15,
            rows: 20,
            tileSize: .init(x: 16, y: 16),
            fill: .empty
        )

        return .init(
            tilemap: tilemap,
            spawnColumn: 7,
            spawnRow: 19
        )
    }()
}
