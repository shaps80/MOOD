import Swift

public struct Path: Equatable, Sendable {
    public enum Command: Equatable, Sendable {
        case move(to: Vec2)
        case addLine(to: Vec2)
        case addRect(Rect)
        case addRoundedRect(
            in: Rect,
            cornerRadius: Double,
            style: RoundedCornerStyle
        )
        case addEllipse(in: Rect)
    }

    public struct Fill: Equatable, Sendable {
        public var color: Color
        public var style: FillStyle
    }

    public struct Stroke: Equatable, Sendable {
        public var color: Color
        public var style: StrokeStyle
    }

    public private(set) var commands: [Command]
    public var fill: Fill?
    public var stroke: Stroke?
    public var strokedStyle: StrokeStyle?
    public var layer: RenderLayer
    public var blendMode: BlendMode
    public var opacity: Double
    public var tint: Color

    public init() {
        self.commands = []
        self.fill = nil
        self.stroke = nil
        self.strokedStyle = nil
        self.layer = 0
        self.blendMode = .normal
        self.opacity = 1
        self.tint = .white
    }

    public init(_ build: (inout Path) -> Void) {
        self.init()
        build(&self)
    }

    public init(_ rect: Rect) {
        self.init()
        addRect(rect)
    }

    public init(
        roundedRect rect: Rect,
        cornerRadius: Double,
        style: RoundedCornerStyle = .continuous
    ) {
        self.init()
        addRoundedRect(in: rect, cornerRadius: cornerRadius, style: style)
    }

    public init(ellipseIn rect: Rect) {
        self.init()
        addEllipse(in: rect)
    }

    public mutating func move(to point: Vec2) {
        commands.append(.move(to: point))
    }

    public mutating func addLine(to point: Vec2) {
        commands.append(.addLine(to: point))
    }

    public mutating func addRect(_ rect: Rect) {
        commands.append(.addRect(rect))
    }

    public mutating func addRoundedRect(
        in rect: Rect,
        cornerRadius: Double,
        style: RoundedCornerStyle = .continuous
    ) {
        commands.append(
            .addRoundedRect(
                in: rect,
                cornerRadius: cornerRadius,
                style: style
            )
        )
    }

    public mutating func addEllipse(in rect: Rect) {
        commands.append(.addEllipse(in: rect))
    }

    public func fill<S: ShapeStyle>(
        _ content: S,
        style: FillStyle = FillStyle()
    ) -> Path {
        var copy = self

        if let strokedStyle, copy.stroke == nil {
            copy.stroke = .init(color: content.resolve(), style: strokedStyle)
        } else {
            copy.fill = .init(color: content.resolve(), style: style)
        }

        return copy
    }

    public func stroke<S: ShapeStyle>(
        _ content: S,
        style: StrokeStyle
    ) -> Path {
        var copy = self
        copy.stroke = .init(color: content.resolve(), style: style)
        return copy
    }

    public func stroke<S: ShapeStyle>(
        _ content: S,
        lineWidth: Double = 1
    ) -> Path {
        stroke(content, style: .init(lineWidth: lineWidth))
    }

    public func strokedPath(_ style: StrokeStyle) -> Path {
        var copy = self
        copy.strokedStyle = style
        return copy
    }

    public func layer(_ layer: RenderLayer) -> Path {
        var copy = self
        copy.layer = layer
        return copy
    }

    public func blendMode(_ blendMode: BlendMode) -> Path {
        var copy = self
        copy.blendMode = blendMode
        return copy
    }

    public func opacity(_ opacity: Double) -> Path {
        var copy = self
        copy.opacity = opacity
        return copy
    }

    public func tint(_ tint: Color) -> Path {
        var copy = self
        copy.tint = tint
        return copy
    }
}
