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
    public let interpolationMode: InterpolationMode
    public private(set) var clearColor = Color(red: 0, green: 0, blue: 0, alpha: 1)
    public private(set) var player: Quad
    public private(set) var playerVelocity: Vec2
    private let playerSpeed = 80.0

    public init(width: Double = 640, height: Double = 320, interpolationMode: InterpolationMode = .nearest) {
        let playerSize = Vec2(x: 16, y: 16)
        size = Vec2(x: width, y: height)
        self.interpolationMode = interpolationMode
        player = Quad(
            position: Vec2(x: (width - playerSize.x) / 2, y: (height - playerSize.y) / 2),
            size: playerSize,
            color: Color(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        )
        playerVelocity = Vec2(x: 0, y: 0)
    }

    public mutating func update(delta: Double, input: InputState = InputState()) {
        let step = max(delta, 0)
        let leftBound = 0.0
        let rightBound = size.x - player.size.x
        let topBound = 0.0
        let bottomBound = size.y - player.size.y
        let velocity = Vec2(x: input.horizontal * playerSpeed, y: input.vertical * playerSpeed)
        let nextX = clamp(player.position.x + (velocity.x * step), min: leftBound, max: rightBound)
        let nextY = clamp(player.position.y + (velocity.y * step), min: topBound, max: bottomBound)

        player = Quad(
            position: Vec2(x: nextX, y: nextY),
            size: player.size,
            color: player.color
        )
        playerVelocity = velocity
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
