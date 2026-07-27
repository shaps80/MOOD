import Swift

public struct LabelStyleConfiguration {
    public typealias Title = StyleContent
    public typealias Icon = StyleContent

    public let title: Title
    public let icon: Icon

    init<Title: View, Icon: View>(title: Title, icon: Icon) {
        self.title = .init(title)
        self.icon = .init(icon)
    }
}
