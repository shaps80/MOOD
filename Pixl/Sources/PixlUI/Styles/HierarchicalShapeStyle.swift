import Swift

@frozen public struct HierarchicalShapeStyle: ShapeStyle, _FixedColorShapeStyle {
    public typealias Resolved = Never

    let level: UInt8
    init(level: UInt8) { self.level = level }

    public static let primary = Self(level: 0)
    public static let secondary = Self(level: 1)
    public static let tertiary = Self(level: 2)
    public static let quaternary = Self(level: 3)
    public static let quinary = Self(level: 4)

    static var color: Color { .primary }

    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        let color: Color
        switch level {
        case 0: color = .primary
        case 1: color = .secondary
        case 2: color = .tertiary
        case 3: color = .quaternary
        default:
            var value = Color.primary
            value.opacity *= 0.08
            color = value
        }
        return graph.internStyle(.color(color))
    }
}

extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: Self { .primary }
    public static var secondary: Self { .secondary }
    public static var tertiary: Self { .tertiary }
    public static var quaternary: Self { .quaternary }
    public static var quinary: Self { .quinary }
}
