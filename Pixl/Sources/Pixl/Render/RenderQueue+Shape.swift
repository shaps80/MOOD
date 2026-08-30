import Pixl2D
import PixlFoundation

extension RenderQueue {
    /// Submits one analytic shape with its model-to-world transform and render intent.
    /// - Parameters:
    ///   - shape: Value-semantic shape snapshot to submit.
    ///   - transform: Model-to-world transform captured with the shape.
    ///   - rendering: Ordering and destination composition for this submission.
    ///   - material: Shading applied to the shape content.
    public func submit(
        _ shape: Shape,
        transform: Transform2D,
        rendering: RenderProperties = .init(),
        material: Pixl2D.Material = .unlit
    ) {
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
            rendering: rendering,
            material: material,
            gradientSlot: gradientSlot
        ))
    }
}
