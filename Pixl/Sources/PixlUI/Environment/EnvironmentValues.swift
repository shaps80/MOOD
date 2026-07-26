import Swift

/// Values inherited by views while building and resolving a view graph.
public struct EnvironmentValues: Sendable {
    /// Current number of presentation pixels per logical screen-space point.
    public internal(set) var displayScale: Float = 1
    var foregroundStyle: ViewGraph.StyleID = .invalid
    var tint: ViewGraph.StyleID = .invalid

    public init() { }

    init(
        displayScale: Float,
        foregroundStyle: ViewGraph.StyleID,
        tint: ViewGraph.StyleID
    ) {
        self.displayScale = displayScale
        self.foregroundStyle = foregroundStyle
        self.tint = tint
    }
}
