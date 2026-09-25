/// Immutable, renderer-independent output. All times are seconds from session origin.
public struct ProfileSnapshot: Sendable {
    public struct Track: Sendable, Identifiable {
        public let id: Int
        public let definitionID: UInt32
        public let instance: Int?
        public let name: String
    }
    public struct Scope: Sendable, Identifiable {
        public let id: UInt32
        public let name: String
        public let kind: ProfileScope.Kind
        public var parentScope: UInt32? = nil
    }
    public struct Segment: Sendable, Identifiable {
        public let id: UInt64
        public let track: Int
        public let scope: UInt32
        public let start: Double
        public let end: Double
        public let correlation: UInt64
        public let detail: UInt32
        public let depth: Int
        public struct Identity: Hashable, Sendable {
            public let track: Int
            public let scope: UInt32
            public let start: Double
            public let end: Double
            public let correlation: UInt64
            public let detail: UInt32
        }
        public var identity: Identity {
            .init(track: track, scope: scope, start: start, end: end, correlation: correlation, detail: detail)
        }
        public var duration: Double { end - start }
    }
    public struct Statistics: Sendable, Identifiable {
        public let id: UInt32
        public let count: Int
        public let average: Double
        public let p95: Double
        public let maximum: Double
    }
    public var tracks: [Track] = []
    public var scopes: [Scope] = []
    public var segments: [Segment] = []
    /// Consumer-built indexes; viewers never regroup or scan the whole trace per lane.
    public var trackSegments: [Int: [Segment]] = [:]
    public var frames: [Segment] = []
    public var gpuFrameIDs: Set<UInt64> = []
    public var correlationEnds: [UInt64: Double] = [:]
    /// Deferred ownership tree. Cross-thread ownership uses explicit scope metadata.
    public var segmentIDsByIdentity: [Segment.Identity: UInt64] = [:]
    public var parents: [UInt64: UInt64] = [:]
    public var children: [UInt64: [UInt64]] = [:]
    public var segmentsByID: [UInt64: Segment] = [:]
    public var statistics: [Statistics] = []
    public var dropped: UInt64 = 0
    public var retainedOut: Int = 0
    public var isRecording = false
    public var generation: UInt64 = 0
    public var start = 0.0
    public var end = 0.0
    public init() {}
}
