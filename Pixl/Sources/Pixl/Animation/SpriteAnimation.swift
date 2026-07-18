import Swift

/// An immutable sequence of sprite regions with uniform frame timing.
public struct SpriteAnimation {
    public let frames: [TextureRegion]
    public let frameDuration: Double
    public let loops: Bool

    public var duration: Double {
        Double(frames.count) * frameDuration
    }

    public init(
        frames: [TextureRegion],
        frameDuration: Double,
        loops: Bool = true
    ) {
        precondition(!frames.isEmpty, "Sprite animation must contain a frame")
        precondition(
            frameDuration.isFinite && frameDuration > 0,
            "Sprite animation frame duration must be finite and positive"
        )

        self.frames = frames
        self.frameDuration = frameDuration
        self.loops = loops
    }

    public func region(at elapsed: Double) -> TextureRegion {
        precondition(elapsed.isFinite, "Sprite animation time must be finite")
        let elapsed = max(elapsed, 0)
        let animationTime = loops
            ? elapsed.truncatingRemainder(dividingBy: duration)
            : min(elapsed, duration)
        let frameIndex = min(
            Int(animationTime / frameDuration),
            frames.count - 1
        )
        return frames[frameIndex]
    }
}

public extension SpriteAnimation {
    /// Mutable playback position for one animation.
    struct Timeline {
        public let animation: SpriteAnimation
        public private(set) var elapsed: Double
        public var speed: Double {
            didSet {
                precondition(
                    speed.isFinite && speed >= 0,
                    "Sprite animation speed must be finite and nonnegative"
                )
            }
        }

        public init(
            animation: SpriteAnimation,
            speed: Double = 1,
            elapsed: Double = 0
        ) {
            precondition(
                speed.isFinite && speed >= 0,
                "Sprite animation speed must be finite and nonnegative"
            )
            precondition(
                elapsed.isFinite && elapsed >= 0,
                "Sprite animation elapsed time must be finite and nonnegative"
            )

            self.animation = animation
            self.speed = speed
            self.elapsed = animation.loops
                ? elapsed.truncatingRemainder(dividingBy: animation.duration)
                : min(elapsed, animation.duration)
        }

        public var region: TextureRegion {
            animation.region(at: elapsed)
        }

        public var isFinished: Bool {
            !animation.loops && elapsed >= animation.duration
        }

        public mutating func advance(by delta: Double) {
            precondition(
                delta.isFinite && delta >= 0,
                "Sprite animation delta must be finite and nonnegative"
            )
            let advance = delta * speed
            precondition(advance.isFinite, "Sprite animation advance must be finite")
            let elapsed = self.elapsed + advance
            self.elapsed = animation.loops
                ? elapsed.truncatingRemainder(dividingBy: animation.duration)
                : min(elapsed, animation.duration)
        }

        public mutating func reset() {
            elapsed = 0
        }
    }
}
