import Pixl2D
import PixlPlatform

public extension Camera2D {
    /// Returns this camera's projection for a render target's dimensions.
    func projection(for output: RenderTarget) -> Transform2D {
        let size = output.texture.descriptor.size
        return projection(
            in: .init(
                Float(size.width),
                Float(size.height)
            )
        )
    }

    /// Returns the world-space axis-aligned bounds visible through a render target.
    func visibleBounds(for output: RenderTarget) -> Rect {
        guard let inverse = projection(for: output).inverted else {
            preconditionFailure("Camera projection must be finite and invertible")
        }
        return inverse.transformed(
            bounds: .init(x: -1, y: -1, width: 2, height: 2)
        )
    }
}
