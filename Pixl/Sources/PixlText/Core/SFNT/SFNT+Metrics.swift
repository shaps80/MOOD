public extension SFNT.FaceMetrics {
    func scaled(to size: Float) -> SFNT.Metrics {
        precondition(size > 0)
        let scale = size / Float(unitsPerEm)
        return .init(
            ascent: Float(ascender) * scale,
            descent: Float(-descender) * scale,
            leading: Float(lineGap) * scale
        )
    }
}
