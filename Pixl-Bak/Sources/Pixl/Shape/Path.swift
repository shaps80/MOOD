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
    var fill: Fill?
    var stroke: Stroke?
    var layer: RenderLayer
    var blendMode: BlendMode
    var opacity: Double
    var tint: Color
    var rotation: Angle

    public init() {
        self.commands = []
        self.fill = nil
        self.stroke = nil
        self.layer = 0
        self.blendMode = .normal
        self.opacity = 1
        self.tint = .white
        self.rotation = .zero
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

    func applying(_ style: RenderStyle, layer: RenderLayer? = nil) -> Path {
        var copy = self

        if let fill = style.fill {
            copy.fill = .init(color: fill, style: style.fillStyle)
        } else {
            copy.fill = nil
        }

        if let stroke = style.stroke {
            copy.stroke = .init(
                color: stroke,
                style: style.strokeStyle ?? StrokeStyle()
            )
        } else {
            copy.stroke = nil
        }

        copy.blendMode = style.blendMode
        copy.opacity = style.opacity
        copy.tint = style.tint

        if let layer {
            copy.layer = layer
        }

        return copy
    }
}
