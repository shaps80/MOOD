import Swift

/// Width of elements in an indexed draw's index buffer.
public enum IndexType: Hashable, Sendable {
    case uint16
    case uint32

    package var byteWidth: UInt64 {
        switch self {
        case .uint16: 2
        case .uint32: 4
        }
    }
}
