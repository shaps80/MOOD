import Swift

public struct Color: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
}

public struct Game {
    public static let clearColors = [
        Color(red: 0.45, green: 0.12, blue: 0.85, alpha: 1),
        Color(red: 0.90, green: 0.06, blue: 0.14, alpha: 1),
        Color(red: 1.00, green: 0.45, blue: 0.02, alpha: 1),
        Color(red: 1.00, green: 0.86, blue: 0.08, alpha: 1)
    ]

    public private(set) var tickCount = 0
    public private(set) var clearColor = Self.clearColors[0]

    public init() {}

    public mutating func tick() {
        tick(elapsedSeconds: tickCount / 60)
    }

    public mutating func tick(elapsedSeconds: Int) {
        tickCount += 1
        clearColor = Self.clearColors[elapsedSeconds % Self.clearColors.count]
    }
}
