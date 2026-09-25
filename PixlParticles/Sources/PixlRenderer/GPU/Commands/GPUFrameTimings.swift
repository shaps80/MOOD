import Swift

/// GPU seconds. Stage intervals may overlap; unavailable counters remain nil.
public struct GPUFrameTimings: Sendable {
    public let total: Double?
    public let preparation: Double?
    public let diagnostics: Double?
    public let draw: Double?
    public let vertex: Double?
    public let fragment: Double?

    public init(total: Double? = nil, preparation: Double? = nil,
                diagnostics: Double? = nil, draw: Double? = nil,
                vertex: Double? = nil, fragment: Double? = nil) {
        self.total = total
        self.preparation = preparation
        self.diagnostics = diagnostics
        self.draw = draw
        self.vertex = vertex
        self.fragment = fragment
    }
}
