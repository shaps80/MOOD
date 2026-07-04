import Pixl

enum GameConfig {
    static let resolution = Vec2(x: 640, y: 320)
    static let tileSize = Vec2(16)
    static let playerSize = Vec2(28)
    static let bulletSize = Vec2(x: 4, y: 12)
    static let invaderSize = Vec2(24)
    static let playerStart = Vec2(x: 320, y: 280)

    static let playBounds = Rect(
        x: tileSize.x,
        y: tileSize.y,
        width: resolution.x - (tileSize.x * 2),
        height: resolution.y - (tileSize.y * 2)
    )
}

