import Swift

public protocol ShapeStyle: Sendable {
    associatedtype Resolved: ShapeStyle = Never
    func resolve(in environment: EnvironmentValues) -> Resolved
}

extension ShapeStyle where Resolved == Never {
    public func resolve(in environment: EnvironmentValues) -> Never {
        fatalError("A terminal ShapeStyle cannot be resolved further")
    }
}

extension Never: ShapeStyle {
    public typealias Resolved = Never
}

public struct AnyShapeStyle: ShapeStyle, @unchecked Sendable {
    public typealias Resolved = Never
    @usableFromInline let box: _AnyShapeStyleBox

    public init<S: ShapeStyle>(_ style: S) {
        box = _ShapeStyleBox(style)
    }
}

extension AnyShapeStyle: _TerminalShapeStyle {
    @usableFromInline func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        box.resolve(in: graph, environment: environment)
    }
}

@usableFromInline protocol _TerminalShapeStyle {
    func resolveStyle(in graph: _Graph, environment: EnvironmentValues) -> ViewGraph.StyleID
}

@usableFromInline class _AnyShapeStyleBox: @unchecked Sendable {
    @usableFromInline func resolve(in graph: _Graph, environment: EnvironmentValues) -> ViewGraph.StyleID {
        fatalError()
    }
}

@usableFromInline final class _ShapeStyleBox<S: ShapeStyle>: _AnyShapeStyleBox, @unchecked Sendable {
    @usableFromInline let style: S
    @usableFromInline init(_ style: S) { self.style = style }

    @usableFromInline override func resolve(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        if let terminal = style as? any _TerminalShapeStyle {
            return terminal.resolveStyle(in: graph, environment: environment)
        }
        let resolved: _AnyShapeStyleBox = _ShapeStyleBox<S.Resolved>(
            style.resolve(in: environment)
        )
        return resolved.resolve(in: graph, environment: environment)
    }
}

@usableFromInline func _resolveShapeStyle<S: ShapeStyle>(
    _ style: S,
    in graph: _Graph,
    environment: EnvironmentValues
) -> ViewGraph.StyleID {
    let box: _AnyShapeStyleBox = _ShapeStyleBox(style)
    return box.resolve(in: graph, environment: environment)
}
