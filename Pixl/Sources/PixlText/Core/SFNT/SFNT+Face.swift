public extension SFNT {
    struct Face: Hashable, Sendable {
        public let id: FaceID
        public let metrics: FaceMetrics
        public let glyphCount: UInt16
        public let tableCount: UInt16
        
        init(
            id: FaceID,
            metrics: FaceMetrics,
            glyphCount: UInt16,
            tableCount: UInt16
        ) {
            self.id = id
            self.metrics = metrics
            self.glyphCount = glyphCount
            self.tableCount = tableCount
        }
    }
}
