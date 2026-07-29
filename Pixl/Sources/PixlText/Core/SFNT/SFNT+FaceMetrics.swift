extension SFNT {
    struct FaceMetrics: Hashable, Sendable {
        let unitsPerEm: UInt16
        let ascender: Int16
        let descender: Int16
        let lineGap: Int16
        
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
