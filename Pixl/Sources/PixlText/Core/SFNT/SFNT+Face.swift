extension SFNT {
    struct Face: Hashable, Sendable {
        let id: FaceID
        let metrics: FaceMetrics
        let glyphCount: UInt16
        let tableCount: UInt16
        let normalizedCoordinates: [Float]
        
        init(
            id: FaceID,
            metrics: FaceMetrics,
            glyphCount: UInt16,
            tableCount: UInt16,
            normalizedCoordinates: [Float] = []
        ) {
            self.id = id
            self.metrics = metrics
            self.glyphCount = glyphCount
            self.tableCount = tableCount
            self.normalizedCoordinates = normalizedCoordinates
        }
    }
}
