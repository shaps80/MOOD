import Pixl2D
import PixlFoundation

extension RenderQueue {
    /// Submits one analytic shape and model-to-world transform to the queue.
    /// - Parameters:
    ///   - shape: Value-semantic shape snapshot to submit.
    ///   - transform: Model-to-world transform captured with the shape.
    public func submit(_ shape: Shape, transform: Transform2D) {
        let gradientSlot: UInt32
        switch shape.fill {
        case .color:
            gradientSlot = .max
        case .gradient(let gradient):
            gradientSlot = registerGradient(
                identity: gradient.storage,
                fingerprint: gradient.fingerprint,
                rgba8: gradient.rgba8
            )
        }
        submit(ShapeSubmission(
            shape: shape,
            transform: transform,
            gradientSlot: gradientSlot
        ))
    }
}
