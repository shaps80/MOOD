import Pixl2D
import PixlPlatform

public extension OrthographicCamera {
    /// Returns an aspect-correct projection for a render target's dimensions.
    /// - Parameter output: Render target supplying width and height.
    /// - Returns: World-to-clip transform for this camera and target aspect ratio.
    func projection(for output: RenderTarget) -> Transform2D {
        let size = output.texture.descriptor.size
        return projection(
            in: .init(
                Float(size.width),
                Float(size.height)
            )
        )
    }

    /// Returns the visible world-space rectangle for a render target.
    /// - Parameter output: Render target supplying width and height.
    func visibleBounds(for output: RenderTarget) -> Rect {
        let size = output.texture.descriptor.size
        return visibleBounds(
            in: .init(
                Float(size.width),
                Float(size.height)
            )
        )
    }
}
