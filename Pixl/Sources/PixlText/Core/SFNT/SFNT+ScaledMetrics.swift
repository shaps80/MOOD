extension SFNT {
    struct Metrics: Hashable, Sendable {
        let ascent: Float
        let descent: Float
        let leading: Float
        
        init(ascent: Float, descent: Float, leading: Float) {
            self.ascent = ascent
            self.descent = descent
            self.leading = leading
        }
    }
}
