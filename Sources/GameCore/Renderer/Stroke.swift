import Swift

public struct Stroke: Equatable, Sendable {
    public let color: Color
    public let width: Double

    public init(color: Color, width: Double = 1) {
        self.color = color
        self.width = width
    }
}
