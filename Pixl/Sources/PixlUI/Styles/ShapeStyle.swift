import Swift

public protocol ShapeStyle: Sendable {
    associatedtype Resolved: ShapeStyle = Never
    func resolve(in environment: EnvironmentValues) -> Resolved
    func opacity(_ opacity: Float) -> OpacityShapeStyleModifier<Self>
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
    let box: _AnyShapeStyleBox

    public init<S: ShapeStyle>(_ style: S) {
        box = _ShapeStyleBox(style)
    }
}

extension AnyShapeStyle: _TerminalShapeStyle {
    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        box.resolve(in: graph, environment: environment)
    }
}

protocol _TerminalShapeStyle {
    func resolveStyle(in graph: _Graph, environment: EnvironmentValues) -> ViewGraph.StyleID
}

protocol _FixedColorShapeStyle: _TerminalShapeStyle {
    static var color: Color { get }
}

extension _FixedColorShapeStyle {
    func resolveStyle(
        in graph: _Graph,
        environment: EnvironmentValues
    ) -> ViewGraph.StyleID {
        graph.internStyle(.color(Self.color))
    }
}

class _AnyShapeStyleBox: @unchecked Sendable {
    func resolve(in graph: _Graph, environment: EnvironmentValues) -> ViewGraph.StyleID {
        fatalError()
    }
}

final class _ShapeStyleBox<S: ShapeStyle>: _AnyShapeStyleBox, @unchecked Sendable {
    let style: S
    init(_ style: S) { self.style = style }

    override func resolve(
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

func _resolveShapeStyle<S: ShapeStyle>(
    _ style: S,
    in graph: _Graph,
    environment: EnvironmentValues
) -> ViewGraph.StyleID {
    let box: _AnyShapeStyleBox = _ShapeStyleBox(style)
    return box.resolve(in: graph, environment: environment)
}
