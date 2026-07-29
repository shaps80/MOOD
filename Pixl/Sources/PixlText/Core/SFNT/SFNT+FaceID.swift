public extension SFNT {
    struct FaceID: Hashable, Sendable {
        public let rawValue: UInt32

        init(rawValue: UInt32) {
            self.rawValue = rawValue
        }
    }
}
