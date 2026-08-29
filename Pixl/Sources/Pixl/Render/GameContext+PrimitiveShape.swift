import Pixl2D
import PixlFoundation

public extension GameContext {
    /// Submits one immediate two-dimensional primitive to the default queue.
    func draw(
        _ shape: PrimitiveShape,
        transform: Transform2D = .identity,
        style: PrimitiveShape.Style,
        layer: RenderLayer = 0,
        order: UInt32 = 0
    ) {
        renderQueue.submit(
            PrimitiveSubmission(
                shape: shape,
                transform: transform,
                style: style,
                layer: layer,
                order: order
            )
        )
    }
}
