import Swift

public struct Game {
    public let size: Vec2
    public let interpolationMode: InterpolationMode
    public private(set) var clearColor = Color(red: 0, green: 0, blue: 0, alpha: 1)
    public private(set) var entities: [Entity]
    private let controlledEntitySpeed: Double = 200
    private let controlledEntityIndex = 0

    public var sprites: [Sprite2D] {
        entities.map(\.sprite)
    }

    public var requiredSpriteAssets: [SpriteAsset] {
        entities.reduce(into: []) { assets, entity in
            if !assets.contains(entity.asset) {
                assets.append(entity.asset)
            }
        }
    }

    public init(width: Double = 640, height: Double = 320, interpolationMode: InterpolationMode = .nearest) {
        size = Vec2(x: width, y: height)
        self.interpolationMode = interpolationMode

        let playerSize = Vec2(x: 16, y: 16)
        let player = Entity(
            position: Vec2(
                x: (width - playerSize.x) / 2,
                y: (height - playerSize.y) / 2
            ),
            size: playerSize,
            asset: .player
        )

        entities = [player]
    }

    public mutating func update(delta: Double, input: InputState) {
        guard entities.indices.contains(controlledEntityIndex) else { return }

        let entity = entities[controlledEntityIndex]
        let step = max(delta, 0)
        let leftBound = 0.0
        let rightBound = size.x - entity.size.x
        let topBound = 0.0
        let bottomBound = size.y - entity.size.y

        let velocity = Vec2(
            x: input.horizontal * controlledEntitySpeed,
            y: input.vertical * controlledEntitySpeed
        )

        let nextX = clamp(
            entity.position.x + (velocity.x * step),
            min: leftBound,
            max: rightBound
        )

        let nextY = clamp(
            entity.position.y + (velocity.y * step),
            min: topBound,
            max: bottomBound
        )

        entities[controlledEntityIndex].move(
            to: Vec2(x: nextX, y: nextY),
            velocity: velocity
        )
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
