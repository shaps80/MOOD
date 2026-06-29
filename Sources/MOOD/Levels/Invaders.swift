import Pixl

extension Level {
    static let invaders: Self = .init(
        tilemap: .init(
            columns: 21,
            rows: 10,
            tileSize: .init(x: 16, y: 16),
            fill: .empty
        ),
        spawnPoint: .init(x: 11, y: 19)
    )
}
