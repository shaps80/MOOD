public extension Font {
    struct Axis: Hashable, Sendable, Identifiable {
        public let tag: String
        public let minimum: Float
        public let defaultValue: Float
        public let maximum: Float

        public var id: String { tag }
    }

    struct NamedInstance: Hashable, Sendable {
        public let nameID: UInt16
        public let coordinates: [Float]
    }
}
