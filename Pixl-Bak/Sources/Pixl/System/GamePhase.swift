import Swift

extension Game {
    /// A named system update phase.
    ///
    /// Pixl provides the built-in phases that map to its update loop. Games can
    /// register additional phases relative to those built-ins, then attach
    /// systems to the phase where they should run.
    ///
    /// ```swift
    /// extension Game.Phase {
    ///     static let ai: Self = "ai"
    /// }
    ///
    /// world.register(phase: .ai, before: .update)
    /// world.addSystem(AISystem(), phase: .ai)
    /// ```
    public struct Phase: Hashable, Sendable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.init(value)
        }

        /// The normal system update phase.
        ///
        /// Systems in this phase run after entity updates and before movement
        /// and collision detection.
        public static let update: Self = "update"

        /// The post-collision system phase.
        ///
        /// Systems in this phase run after movement, collision detection, and
        /// entity collision callbacks, before frame events are flushed and the
        /// camera is resolved for rendering.
        public static let postCollision: Self = "postCollision"
    }
}

