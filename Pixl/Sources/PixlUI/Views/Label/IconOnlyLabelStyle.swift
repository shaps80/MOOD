import Swift

public struct IconOnlyLabelStyle: LabelStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.icon
    }
}

extension LabelStyle where Self == IconOnlyLabelStyle {
    public static var iconOnly: Self { .init() }
}
