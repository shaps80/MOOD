import Swift

public struct Game {
    public private(set) var tickCount = 0
    public init() {}
    public mutating func tick() {
        tickCount += 1
    }
}
