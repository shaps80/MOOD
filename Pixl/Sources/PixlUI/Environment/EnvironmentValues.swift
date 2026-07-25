import Swift

/// Values inherited by views while building and resolving a view graph.
public struct EnvironmentValues: Sendable {
    @usableFromInline var foregroundStyle: ViewGraph.StyleID = .invalid

    public init() { }

    @usableFromInline init(foregroundStyle: ViewGraph.StyleID) {
        self.foregroundStyle = foregroundStyle
    }
}
