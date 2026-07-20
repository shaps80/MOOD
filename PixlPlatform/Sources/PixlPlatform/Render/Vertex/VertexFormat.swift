import Swift

/// Scalar representation and component count of one vertex attribute.
public enum VertexFormat: Hashable, Sendable {
    /// Two unsigned 8-bit integer components.
    case uint8x2
    /// Four unsigned 8-bit integer components.
    case uint8x4
    /// Two signed 8-bit integer components.
    case sint8x2
    /// Four signed 8-bit integer components.
    case sint8x4
    /// Two unsigned normalized 8-bit components.
    case unorm8x2
    /// Four unsigned normalized 8-bit components.
    case unorm8x4
    /// Two signed normalized 8-bit components.
    case snorm8x2
    /// Four signed normalized 8-bit components.
    case snorm8x4
    /// Two unsigned 16-bit integer components.
    case uint16x2
    /// Four unsigned 16-bit integer components.
    case uint16x4
    /// Two signed 16-bit integer components.
    case sint16x2
    /// Four signed 16-bit integer components.
    case sint16x4
    /// Two unsigned normalized 16-bit components.
    case unorm16x2
    /// Four unsigned normalized 16-bit components.
    case unorm16x4
    /// Two signed normalized 16-bit components.
    case snorm16x2
    /// Four signed normalized 16-bit components.
    case snorm16x4
    /// Two 16-bit floating-point components.
    case float16x2
    /// Four 16-bit floating-point components.
    case float16x4
    /// One 32-bit floating-point component.
    case float32
    /// Two 32-bit floating-point components.
    case float32x2
    /// Three 32-bit floating-point components.
    case float32x3
    /// Four 32-bit floating-point components.
    case float32x4
    /// One unsigned 32-bit integer component.
    case uint32
    /// Two unsigned 32-bit integer components.
    case uint32x2
    /// Three unsigned 32-bit integer components.
    case uint32x3
    /// Four unsigned 32-bit integer components.
    case uint32x4
    /// One signed 32-bit integer component.
    case sint32
    /// Two signed 32-bit integer components.
    case sint32x2
    /// Three signed 32-bit integer components.
    case sint32x3
    /// Four signed 32-bit integer components.
    case sint32x4
}
