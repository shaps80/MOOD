import PixlGraphics

package struct TextureCoordinates: BitwiseCopyable, Sendable {
    package var origin: SIMD2<Float>
    package var scale: SIMD2<Float>

    package init(
        origin: SIMD2<Float> = .zero,
        scale: SIMD2<Float> = .init(repeating: 1)
    ) {
        self.origin = origin
        self.scale = scale
    }
}

/// Triangle geometry in two-dimensional space.
public struct Triangle: Sendable {
    public var a: Vec2
    public var b: Vec2
    public var c: Vec2
    public var colors: (Color, Color, Color)

    public init(
        a: Vec2 = .init(0, 0.5),
        b: Vec2 = .init(-0.5, -0.5),
        c: Vec2 = .init(0.5, -0.5),
        colors: (Color, Color, Color) = (
            .yellow,
            .cyan,
            .pink
        )
    ) {
        self.a = a
        self.b = b
        self.c = c
        self.colors = colors
    }

    public init(
        a: Vec2 = .init(0, 0.5),
        b: Vec2 = .init(-0.5, -0.5),
        c: Vec2 = .init(0.5, -0.5),
        color: Color
    ) {
        self.init(a: a, b: b, c: c, colors: (color, color, color))
    }
}

/// Four-vertex geometry in two-dimensional space.
///
/// Rendering may triangulate the vertices as `(0, 1, 2)` and `(0, 2, 3)`.
public struct Quad: Sendable {
    public var topLeft: Vec2
    public var bottomLeft: Vec2
    public var bottomRight: Vec2
    public var topRight: Vec2
    public var colors: (Color, Color, Color, Color)

    public init(
        topLeft: Vec2 = .init(-0.5, 0.5),
        bottomLeft: Vec2 = .init(-0.5, -0.5),
        bottomRight: Vec2 = .init(0.5, -0.5),
        topRight: Vec2 = .init(0.5, 0.5),
        colors: (Color, Color, Color, Color) = (
            .yellow,
            .cyan,
            .pink,
            .white
        )
    ) {
        self.topLeft = topLeft
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.topRight = topRight
        self.colors = colors
    }

    public init(
        topLeft: Vec2 = .init(-0.5, 0.5),
        bottomLeft: Vec2 = .init(-0.5, -0.5),
        bottomRight: Vec2 = .init(0.5, -0.5),
        topRight: Vec2 = .init(0.5, 0.5),
        color: Color
    ) {
        self.init(
            topLeft: topLeft,
            bottomLeft: bottomLeft,
            bottomRight: bottomRight,
            topRight: topRight,
            colors: (color, color, color, color)
        )
    }
}
