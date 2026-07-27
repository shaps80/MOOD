import Swift

public extension Mouse {
    /// One chronological mouse-motion measurement supplied by the platform.
    struct Sample: Hashable, Sendable {
        public let timestamp: Double
        public let location: SIMD2<Float>
        public let translation: SIMD2<Float>

        public init(
            timestamp: Double,
            location: SIMD2<Float>,
            translation: SIMD2<Float>
        ) {
            self.timestamp = timestamp
            self.location = location
            self.translation = translation
        }
    }
}
