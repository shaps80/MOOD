import Swift

public extension Mouse {
    /// Portable mouse-button identity with room for platform-specific extra buttons.
    struct Button: RawRepresentable, Hashable, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let primary = Self(rawValue: 0)
        public static let secondary = Self(rawValue: 1)
        public static let tertiary = Self(rawValue: 2)
    }
}

public extension Mouse.Button {
    enum Phase: Hashable, Sendable {
        case down
        case up
    }

    struct Event: Hashable, Sendable {
        public let timestamp: Double
        public let button: Mouse.Button
        public let phase: Phase
        public let rawLocation: SIMD2<Float>
        public let modifiers: Key.Modifiers

        public init(
            timestamp: Double,
            button: Mouse.Button,
            phase: Phase,
            rawLocation: SIMD2<Float>,
            modifiers: Key.Modifiers = []
        ) {
            self.timestamp = timestamp
            self.button = button
            self.phase = phase
            self.rawLocation = rawLocation
            self.modifiers = modifiers
        }
    }
}
