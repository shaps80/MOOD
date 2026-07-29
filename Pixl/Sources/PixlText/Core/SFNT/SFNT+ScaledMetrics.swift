public extension SFNT {
    struct Metrics: Hashable, Sendable {
        public let ascent: Float
        public let descent: Float
        public let leading: Float
        
        init(ascent: Float, descent: Float, leading: Float) {
            self.ascent = ascent
            self.descent = descent
            self.leading = leading
        }
    }
}
