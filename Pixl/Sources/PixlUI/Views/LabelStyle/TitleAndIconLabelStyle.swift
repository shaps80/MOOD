import Swift

public struct TitleAndIconLabelStyle: LabelStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == TitleAndIconLabelStyle {
    public static var titleAndIcon: Self { .init() }
}
