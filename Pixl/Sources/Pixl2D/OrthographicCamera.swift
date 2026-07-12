import PixlPlatform
import PixlMath

/// A y-up orthographic camera centred on a world-space position.
///
/// `halfHeight` defines the visible vertical world span. For example, a camera
/// with `center: .zero` and `halfHeight: 1` shows y coordinates from `-1` to
/// `1`; its visible width is derived from the render target's aspect ratio.
public struct OrthographicCamera: Sendable {
    /// World-space position displayed at the centre of the render target.
    public var center: Vec2

    /// Half of the visible vertical world span.
    ///
    /// A value of `1` shows y coordinates from `-1` to `1`. Larger values zoom
    /// out; smaller positive values zoom in.
    public var halfHeight: Double

    /// Creates an aspect-correct y-up orthographic camera.
    ///
    /// - Parameters:
    ///   - center: World-space point placed at the centre of the render target.
    ///     Use `.zero` for a camera centred on the world origin.
    ///   - halfHeight: Half the visible vertical world span. For example, `1`
    ///     shows y coordinates from `-1` to `1`; `5` shows y coordinates from
    ///     `-5` to `5`.
    public init(center: Vec2 = .zero, halfHeight: Double = 1) {
        precondition(halfHeight > 0)
        self.center = center
        self.halfHeight = halfHeight
    }

    /// Returns the world-to-clip transform for a render target.
    ///
    /// - Parameter output: Current render target. Its dimensions determine the
    ///   visible width, preserving world-space aspect ratio.
    public func projection(for output: RenderTarget) -> Transform2D {
        let size = output.texture.descriptor.size
        precondition(size.width > 0)
        precondition(size.height > 0)

        let halfWidth = halfHeight * Double(size.width) / Double(size.height)
        let xScale = Float(1 / halfWidth)
        let yScale = Float(1 / halfHeight)

        return .init(
            x: .init(xScale, 0, 0),
            y: .init(0, yScale, 0),
            translation: .init(
                Float(-center.x) * xScale,
                Float(-center.y) * yScale,
                1
            )
        )
    }
}
