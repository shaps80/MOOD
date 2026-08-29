import Swift

public extension Mouse {
    /// One chronological mouse-motion measurement supplied by the platform.
    struct Sample: Hashable, Sendable {
        public let timestamp: Double
        public let rawLocation: SIMD2<Float>
        public let rawTranslation: SIMD2<Float>

        public init(
            timestamp: Double,
            rawLocation: SIMD2<Float>,
            rawTranslation: SIMD2<Float>
        ) {
            self.timestamp = timestamp
            self.rawLocation = rawLocation
            self.rawTranslation = rawTranslation
        }
    }
}
