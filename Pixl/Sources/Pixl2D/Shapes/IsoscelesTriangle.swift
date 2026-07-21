/// Centred isosceles triangle geometry.
public struct IsoscelesTriangle: Hashable, Sendable {
    /// Base width.
    public let width: Float
    /// Height from base to apex.
    public let height: Float
    /// Creates a unit-sized isosceles triangle.
    public init() { self.init(width: 1, height: 1) }
    /// Creates an isosceles triangle.
    /// - Parameters:
    ///   - width: Positive base width.
    ///   - height: Positive height.
    public init(width: Float, height: Float) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0)
        self.width = width; self.height = height
    }
    /// Unit-sized isosceles triangle.
    public static var isoscelesTriangle: Self { .init() }
    /// Explicit isosceles triangle.
    public static func isoscelesTriangle(width: Float, height: Float) -> Self { .init(width: width, height: height) }
}
