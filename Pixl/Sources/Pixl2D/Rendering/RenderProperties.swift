/// Ordering and destination-composition properties captured by one submission.
public struct RenderProperties: Equatable, Sendable {
    /// Coarse render layer. Lower layers render first.
    public var layer: RenderLayer
    /// Ordering within ``layer``. Lower values render first.
    public var order: UInt32
    /// Fixed-function composition over the destination.
    public var blendMode: BlendMode

    public init(
        layer: RenderLayer = 0,
        order: UInt32 = 0,
        blendMode: BlendMode = .normal
    ) {
        self.layer = layer
        self.order = order
        self.blendMode = blendMode
    }
}

public extension RenderProperties {
    /// Fixed-function composition applied to the shaded output.
    enum BlendMode: Equatable, Sendable {
        /// Source-over composition matching the submitted content's alpha representation.
        case normal
        /// Replaces the destination with the shaded output.
        case replace
    }
}
