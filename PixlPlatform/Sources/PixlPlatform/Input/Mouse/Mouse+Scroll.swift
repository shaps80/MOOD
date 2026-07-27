import Swift

public extension Mouse {
    enum ScrollUnit: Hashable, Sendable {
        case pixel
        case line
        case page
    }

    struct ScrollEvent: Hashable, Sendable {
        public let timestamp: Double
        public let location: SIMD2<Float>
        public let translation: SIMD2<Float>
        public let unit: ScrollUnit

        public init(
            timestamp: Double,
            location: SIMD2<Float>,
            translation: SIMD2<Float>,
            unit: ScrollUnit
        ) {
            self.timestamp = timestamp
            self.location = location
            self.translation = translation
            self.unit = unit
        }
    }
}
