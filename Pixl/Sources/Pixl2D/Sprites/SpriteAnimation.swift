import Swift

/// An immutable sequence of sprite regions with uniform frame timing.
public struct SpriteAnimation: Sendable {
    /// Texture regions displayed in playback order.
    public let frames: [TextureRegion]
    /// Seconds for which each frame is displayed.
    public let frameDuration: Double
    /// Whether playback wraps after the final frame.
    public let loops: Bool

    /// Total duration of one pass through every frame, in seconds.
    public var duration: Double {
        Double(frames.count) * frameDuration
    }

    /// Creates a uniformly timed sprite animation.
    ///
    /// - Parameters:
    ///   - frames: Nonempty sequence of texture regions in playback order.
    ///   - frameDuration: Positive finite duration of each frame, in seconds.
    ///   - loops: Whether playback wraps after the final frame.
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

    /// Selects the region displayed at a playback time.
    /// - Parameter elapsed: Finite elapsed playback time in seconds. Negative values select the first frame.
    /// - Returns: The current texture region, wrapping or clamping according to `loops`.
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
    struct Timeline: Sendable {
        /// Animation controlled by this timeline.
        public var animation: SpriteAnimation
        /// Current playback position, in seconds.
        public private(set) var elapsed: Double
        /// Nonnegative playback multiplier. `0` pauses the timeline.
        public var speed: Double {
            didSet {
                precondition(
                    speed.isFinite && speed >= 0,
                    "Sprite animation speed must be finite and nonnegative"
                )
            }
        }

        /// Creates mutable playback state for an animation.
        /// - Parameters:
        ///   - animation: Animation to play.
        ///   - speed: Nonnegative finite playback multiplier.
        ///   - elapsed: Nonnegative finite initial playback time, in seconds.
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

        /// Texture region displayed at the current playback position.
        public var region: TextureRegion {
            animation.region(at: elapsed)
        }

        /// Whether a non-looping animation has reached its end.
        public var isFinished: Bool {
            !animation.loops && elapsed >= animation.duration
        }

        /// Advances playback by a presentation-time interval.
        /// - Parameter delta: Nonnegative finite elapsed time, in seconds, before applying `speed`.
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

        /// Returns playback to the first frame without changing animation or speed.
        public mutating func reset() {
            elapsed = 0
        }
    }
}
