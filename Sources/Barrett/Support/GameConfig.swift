import Pixl

enum GameConfig {
    static let resolution = Vec2(x: 1600, y: 1000)
    static let tileSize = Vec2(16)
    static let playerSize = Vec2(48)
    static let bulletSize = Vec2(x: 8, y: 8)
    static let invaderSize = Vec2(48)
    static let playerStart = Vec2(x: 800, y: 820)

    static let playBounds = Rect(
        x: tileSize.x,
        y: tileSize.y,
        width: resolution.x - (tileSize.x * 2),
        height: resolution.y - (tileSize.y * 2)
    )
}
