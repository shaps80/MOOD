import Swift

public final class Scene<Content: View> {
    @usableFromInline let root: ViewGraphRoot<Content>

    public init(_ content: Content) {
        root = ViewGraph.build { content }
    }

    public init(
        @ContentBuilder content: () -> Content
    ) {
        root = ViewGraph.build(content: content)
    }
}
