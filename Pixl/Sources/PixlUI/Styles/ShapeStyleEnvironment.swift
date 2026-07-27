import Swift

extension EnvironmentValues {
    @Entry public var foregroundStyle: AnyShapeStyle = .init(
        HierarchicalShapeStyle.primary
    )

    @Entry public var tint: AnyShapeStyle = .init(Color.orange)
}
