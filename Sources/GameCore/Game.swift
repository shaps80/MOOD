import Swift

public struct Color: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
}

public struct Vec2: Equatable, Sendable {
    public let x: Double
    public let y: Double
}

public struct Quad: Equatable, Sendable {
    public let position: Vec2
    public let size: Vec2
    public let color: Color
}

public struct Game {
    public let size: Vec2
    public private(set) var clearColor = Color(red: 0, green: 0, blue: 0, alpha: 1)
    public private(set) var player: Quad
    public private(set) var playerVelocity: Vec2

    public init(width: Double = 640, height: Double = 320) {
        let playerSize = Vec2(x: 16, y: 16)
        size = Vec2(x: width, y: height)
        player = Quad(
            position: Vec2(x: 0, y: (height - playerSize.y) / 2),
            size: playerSize,
            color: Color(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        )
        playerVelocity = Vec2(x: 80, y: 0)
    }

    public mutating func update(delta: Double) {
        let step = max(delta, 0)
        let leftBound = 0.0
        let rightBound = size.x - player.size.x
        var nextX = player.position.x + (playerVelocity.x * step)
        var nextVelocityX = playerVelocity.x

        if nextX > rightBound {
            nextX = rightBound - (nextX - rightBound)
            nextVelocityX = -abs(nextVelocityX)
        } else if nextX < leftBound {
            nextX = leftBound + (leftBound - nextX)
            nextVelocityX = abs(nextVelocityX)
        }

        player = Quad(
            position: Vec2(x: nextX, y: player.position.y),
            size: player.size,
            color: player.color
        )
        playerVelocity = Vec2(x: nextVelocityX, y: playerVelocity.y)
    }
}
