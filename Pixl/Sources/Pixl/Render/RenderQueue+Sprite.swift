import Pixl2D
import PixlFoundation

extension RenderQueue {
    /// Submits one sprite and model-to-world transform to the queue.
    /// - Parameters:
    ///   - sprite: Value-semantic sprite snapshot to submit.
    ///   - transform: Model-to-world transform captured with the sprite.
    public func submit(_ sprite: Sprite, transform: Transform2D) {
        submit(SpriteSubmission(sprite: sprite, transform: transform))
    }
}
