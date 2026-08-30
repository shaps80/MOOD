import Pixl2D

struct AnimatedSprite: Sendable {
    private(set) var sprite: Sprite
    private var timeline: SpriteAnimation.Timeline

    init(animation: SpriteAnimation) {
        timeline = .init(animation: animation)
        sprite = .init(region: timeline.region)
    }

    mutating func play(
        _ animation: SpriteAnimation,
        speed: Double = 1
    ) {
        timeline.animation = animation
        timeline.speed = speed
        timeline.reset()
        sprite.region = timeline.region
    }

    mutating func advance(by delta: Double) {
        timeline.advance(by: delta)
        sprite.region = timeline.region
    }
}
