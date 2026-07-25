import Swift

@resultBuilder
public struct ViewBuilder {
    @inlinable public static func buildExpression<Content>(
        _ content: Content
    ) -> Content {
        content
    }

    @inlinable public static func buildBlock() -> EmptyContent {
        EmptyContent()
    }

    @inlinable public static func buildBlock<Content>(
        _ content: Content
    ) -> Content {
        content
    }

    @_disfavoredOverload
    @inlinable public static func buildBlock<each Content>(
        _ content: repeat each Content
    ) -> TupleContent<repeat each Content> {
        TupleContent(repeat each content)
    }

    @inlinable public static func buildEither<TrueContent, FalseContent>(
        first: TrueContent
    ) -> _ConditionalContent<TrueContent, FalseContent> {
        .init(storage: .trueContent(first))
    }

    @inlinable public static func buildEither<TrueContent, FalseContent>(
        second: FalseContent
    ) -> _ConditionalContent<TrueContent, FalseContent> {
        .init(storage: .falseContent(second))
    }

    @inlinable public static func buildIf<Content>(
        _ content: Content?
    ) -> Content? {
        content
    }
}

public typealias ContentBuilder = ViewBuilder
