import Swift

public struct GroundPlane: Sendable {
    public static let defaultHeight: Float = -100
    public static let defaultExtent: Float = 500

    public enum Style: UInt32, Sendable {
        case grid
        case horizon
    }

    public var isVisible: Bool
    public var style: Style
    public var height: Float
    public var extent: Float
    public var spacing: Float

    public init(
        isVisible: Bool = false,
        style: Style = .grid,
        height: Float = defaultHeight,
        extent: Float = defaultExtent,
        spacing: Float = 50
    ) {
        precondition(extent > 0)
        precondition(spacing > 0)
        self.isVisible = isVisible
        self.style = style
        self.height = height
        self.extent = extent
        self.spacing = spacing
    }
}
