import Swift

public struct TitleOnlyLabelStyle: LabelStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.title
    }
}

extension LabelStyle where Self == TitleOnlyLabelStyle {
    public static var titleOnly: Self { .init() }
}
