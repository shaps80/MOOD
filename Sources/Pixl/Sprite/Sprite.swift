import Swift

public struct Sprite: Equatable, Sendable {
    public var position: Vec2
    public var size: Vec2
    public var material: Material
    public var layer: RenderLayer
    public var blendMode: BlendMode
    public var opacity: Double
    public var tint: Color

    public init(
        position: Vec2,
        size: Vec2,
        material: Material,
        layer: RenderLayer = 0,
        blendMode: BlendMode = .normal,
        opacity: Double = 1,
        tint: Color = .white
    ) {
        self.position = position
        self.size = size
        self.material = material
        self.layer = layer
        self.blendMode = blendMode
        self.opacity = opacity
        self.tint = tint
    }
}
