import Swift

public struct CameraEffects: Equatable, Sendable {
    public var offset: Vec2

    public init(offset: Vec2 = .zero) {
        self.offset = offset
    }
}
