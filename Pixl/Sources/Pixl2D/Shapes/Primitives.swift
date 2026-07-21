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
    /// First vertex.
    public var a: Vec2
    /// Second vertex.
    public var b: Vec2
    /// Third vertex.
    public var c: Vec2
    /// Per-vertex colours corresponding to `a`, `b`, and `c`.
    public var colors: (Color, Color, Color)

    /// Creates a triangle with independently coloured vertices.
    ///
    /// - Parameters:
    ///   - a: First vertex.
    ///   - b: Second vertex.
    ///   - c: Third vertex.
    ///   - colors: Colours corresponding to `a`, `b`, and `c`.
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

    /// Creates a uniformly coloured triangle.
    ///
    /// - Parameters:
    ///   - a: First vertex.
    ///   - b: Second vertex.
    ///   - c: Third vertex.
    ///   - color: Colour assigned to every vertex.
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
    /// Top-left vertex.
    public var topLeft: Vec2
    /// Bottom-left vertex.
    public var bottomLeft: Vec2
    /// Bottom-right vertex.
    public var bottomRight: Vec2
    /// Top-right vertex.
    public var topRight: Vec2
    /// Per-vertex colours in the same order as the four vertex properties.
    public var colors: (Color, Color, Color, Color)

    /// Creates a quad with independently coloured vertices.
    ///
    /// - Parameters:
    ///   - topLeft: Top-left vertex.
    ///   - bottomLeft: Bottom-left vertex.
    ///   - bottomRight: Bottom-right vertex.
    ///   - topRight: Top-right vertex.
    ///   - colors: Colours corresponding to the four vertices.
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

    /// Creates a uniformly coloured quad.
    ///
    /// - Parameters:
    ///   - topLeft: Top-left vertex.
    ///   - bottomLeft: Bottom-left vertex.
    ///   - bottomRight: Bottom-right vertex.
    ///   - topRight: Top-right vertex.
    ///   - color: Colour assigned to every vertex.
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
