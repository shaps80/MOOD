import Pixl2D
import PixlFoundation

extension RenderQueue {
    /// Submits one sprite with its model-to-world transform and render intent.
    /// - Parameters:
    ///   - sprite: Value-semantic sprite snapshot to submit.
    ///   - transform: Model-to-world transform captured with the sprite.
    ///   - rendering: Ordering and destination composition for this submission.
    ///   - material: Shading applied to the sprite content.
    public func submit(
        _ sprite: Sprite,
        transform: Sprite.Transform,
        rendering: RenderProperties = .init(),
        material: Pixl2D.Material = .unlit
    ) {
        submit(SpriteSubmission(
            sprite: sprite,
            transform: transform,
            rendering: rendering,
            material: material
        ))
    }
}
