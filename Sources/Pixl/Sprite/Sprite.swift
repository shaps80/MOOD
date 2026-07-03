import Swift

public struct Sprite: Equatable, Sendable {
    public var material: Material
    public var transform: Transform
    public var layer: RenderLayer
    public var blendMode: BlendMode
    public var opacity: Double
    public var tint: Color

    public init(
        material: Material,
        transform: Transform = .identity,
        layer: RenderLayer = 0,
        blendMode: BlendMode = .normal,
        opacity: Double = 1,
        tint: Color = .white
    ) {
        self.material = material
        self.transform = transform
        self.layer = layer
        self.blendMode = blendMode
        self.opacity = opacity
        self.tint = tint
    }
}

extension Sprite {
    var naturalSize: Vec2 {
        material.naturalSize ?? .zero
    }
}
