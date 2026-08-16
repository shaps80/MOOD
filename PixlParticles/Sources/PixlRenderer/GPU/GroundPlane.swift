import Swift

public struct GroundPlane: Sendable {
    public enum Style: UInt32, Sendable {
        case grid
        case horizon
    }

    public var isVisible: Bool
    public var style: Style
    public var height: Float
    public var extent: Float
    public var spacing: Float
    public var viewProjection: Matrix4x4

    public init(
        isVisible: Bool = false,
        style: Style = .grid,
        height: Float = -100,
        extent: Float = 500,
        spacing: Float = 50,
        viewProjection: Matrix4x4 = .identity
    ) {
        self.isVisible = isVisible
        self.style = style
        self.height = height
        self.extent = extent
        self.spacing = spacing
        self.viewProjection = viewProjection
    }
}
