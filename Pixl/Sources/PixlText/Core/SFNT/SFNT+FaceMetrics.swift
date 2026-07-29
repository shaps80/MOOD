public extension SFNT {
    struct FaceMetrics: Hashable, Sendable {
        public let unitsPerEm: UInt16
        public let ascender: Int16
        public let descender: Int16
        public let lineGap: Int16
        
        init(
            unitsPerEm: UInt16,
            ascender: Int16,
            descender: Int16,
            lineGap: Int16
        ) {
            self.unitsPerEm = unitsPerEm
            self.ascender = ascender
            self.descender = descender
            self.lineGap = lineGap
        }
    }
}
