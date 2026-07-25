import Swift

@frozen public struct TupleContent<each Content> {
    public var body: Never { fatalError() }
    public var content: (repeat each Content)

    @inlinable public init(_ content: repeat each Content) {
        self.content = (repeat each content)
    }
}

extension TupleContent: View where repeat each Content: View { }
