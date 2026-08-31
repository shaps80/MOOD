import Swift

public enum RegionKind: Hashable, Sendable {
    case indexedBuffer
    case densePool
}

/// Marker type declaring byte-addressed region storage.
public enum RawBytes: Sendable {}
