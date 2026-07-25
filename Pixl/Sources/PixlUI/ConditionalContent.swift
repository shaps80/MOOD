import Swift

@frozen public struct _ConditionalContent<TrueContent, FalseContent> {
    public var body: Never { fatalError() }

    @usableFromInline let storage: Storage
    @usableFromInline init(storage: Storage) {
        self.storage = storage
    }

    @usableFromInline @frozen 
    internal enum Storage {
        case trueContent(TrueContent)
        case falseContent(FalseContent)
    }
}

extension _ConditionalContent: View where TrueContent: View, FalseContent: View {
    public static func _makeView(
        view: _GraphValue<Self>,
        inputs: _ViewInputs
    ) -> _ViewOutputs {
        .init()
    }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never

    public var body: Never { fatalError() }
}
