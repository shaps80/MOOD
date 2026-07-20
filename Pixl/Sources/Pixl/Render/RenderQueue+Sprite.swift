import Pixl2D
import PixlFoundation

extension RenderQueue {
    public func submit(_ sprite: Sprite, transform: Transform2D) {
        submit(SpriteSubmission(sprite: sprite, transform: transform))
    }
}
