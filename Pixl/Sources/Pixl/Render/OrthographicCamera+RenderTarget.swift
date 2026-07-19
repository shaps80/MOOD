import Pixl2D
import PixlPlatform

public extension OrthographicCamera {
    func projection(for output: RenderTarget) -> Transform2D {
        let size = output.texture.descriptor.size
        return projection(
            in: .init(
                Double(size.width),
                Double(size.height)
            )
        )
    }
}
