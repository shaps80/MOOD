import PixlFoundation
import PixlGraphics
import PixlPlatform
import Pixl2D
import PixlUI

final class SceneCompilation {
    weak var scene: AnyObject?
    let generation: UInt64
    let size: Size
    let displayScale: Float
    let submissions: ContiguousArray<RenderQueue.Submission>
    let inputHandlers: ContiguousArray<ViewGraph.InputHandler>

    init<Content: View>(
        scene: Scene<Content>,
        size: Size,
        displayScale: Float,
        context: GameContext
    ) throws {
        let prepared = try scene.prepare(
            size: size,
            displayScale: displayScale,
            resolveImage: { try context.assets.loadUITexture(named: $0) }
        )
        self.scene = scene
        generation = scene.generation
        self.size = size
        self.displayScale = displayScale
        inputHandlers = prepared.root.graph.inputHandlers
        for handler in inputHandlers {
            context.inputs.bind(handler.input)
        }
        submissions = Self.lower(
            graph: prepared.root.graph,
            layout: prepared.layout
        )
    }

    func matches<Content: View>(
        scene: Scene<Content>,
        size: Size,
        displayScale: Float
    ) -> Bool {
        self.scene === scene
            && generation == scene.generation
            && self.size == size
            && self.displayScale == displayScale
    }

    func dispatchInputs() {
        for handler in inputHandlers {
            if handler.phases & 1 != 0, handler.input.is(.down) {
                handler.action(handler.input, .down)
            }
            if handler.phases & 2 != 0, handler.input.is(.up) {
                handler.action(handler.input, .up)
            }
        }
    }

    private static func lower(
        graph: ViewGraph,
        layout: ViewLayout
    ) -> ContiguousArray<RenderQueue.Submission> {
        var submissions: ContiguousArray<RenderQueue.Submission> = []
        submissions.reserveCapacity(graph.primitives.count + graph.shapes.count)

        for (index, node) in graph.nodes.enumerated() {
            guard !node.isHidden else { continue }
            let frame = layout.frames[index]
            guard frame.size.width > 0, frame.size.height > 0 else { continue }

            switch node.kind {
            case .primitive:
                switch graph.primitives[Int(node.payload)] {
                case .fill(let style):
                    let fill = color(for: style, in: graph)
                    guard fill.opacity > 0 else { continue }
                    submissions.append(
                        .shape(rectangle(
                            frame: frame,
                            fill: fill,
                            stroke: .clear,
                            strokeWidth: 0
                        ))
                    )
                case .image(let image):
                    guard let asset = image.asset else { continue }
                    let sourceSize = Size(
                        x: Float(asset.size.x),
                        y: Float(asset.size.y)
                    )
                    var sprite = Sprite(region: .init(asset: asset))
                    if image.renderingMode == .template {
                        sprite.modulation = color(for: image.tint, in: graph)
                        sprite.modulationMode = .alphaMask
                    }
                    let transform = Transform2D(
                        frame.origin + frame.size * 0.5,
                        scale: .init(
                            frame.size.x / sourceSize.x,
                            -frame.size.y / sourceSize.y
                        )
                    )
                    submissions.append(
                        .sprite(.init(sprite: sprite, transform: transform))
                    )
                default:
                    continue
                }

            case .shape:
                let shape = graph.shapes[Int(node.payload)]
                switch shape.path(in: frame, displayScale: layout.displayScale) {
                case .rectangle(let rect, let cornerRadius):
                    let fill = color(for: shape.fill, in: graph)
                    let stroke = shape.stroke.map {
                        color(for: $0.style, in: graph)
                    } ?? .clear
                    guard fill.opacity > 0 || stroke.opacity > 0 else { continue }
                    submissions.append(
                        .shape(rectangle(
                            frame: rect,
                            fill: fill,
                            stroke: stroke,
                            strokeWidth: shape.stroke?.lineWidth ?? 0,
                            cornerRadius: cornerRadius
                        ))
                    )
                case .unevenRoundedRectangle(let rect, let cornerRadii):
                    let fill = color(for: shape.fill, in: graph)
                    let stroke = shape.stroke.map {
                        color(for: $0.style, in: graph)
                    } ?? .clear
                    guard fill.opacity > 0 || stroke.opacity > 0 else { continue }
                    submissions.append(
                        .shape(unevenRoundedRectangle(
                            frame: rect,
                            cornerRadii: cornerRadii,
                            fill: fill,
                            stroke: stroke,
                            strokeWidth: shape.stroke?.lineWidth ?? 0
                        ))
                    )
                case .circle(let rect):
                    let fill = color(for: shape.fill, in: graph)
                    let stroke = shape.stroke.map {
                        color(for: $0.style, in: graph)
                    } ?? .clear
                    guard fill.opacity > 0 || stroke.opacity > 0 else { continue }
                    submissions.append(
                        .shape(circle(
                            frame: rect,
                            fill: fill,
                            stroke: stroke,
                            strokeWidth: shape.stroke?.lineWidth ?? 0
                        ))
                    )
                }

            default:
                continue
            }
        }

        return submissions
    }

    private static func color(
        for style: ViewGraph.StyleID,
        in graph: ViewGraph
    ) -> PixlGraphics.Color {
        switch graph.styles[Int(style.rawValue)] {
        case .color(let color): color
        }
    }

    private static func rectangle(
        frame: Rect,
        fill: PixlGraphics.Color,
        stroke: PixlGraphics.Color,
        strokeWidth: Float,
        cornerRadius: Float = 0
    ) -> ShapeSubmission {
        let outerHalfSize = frame.size * 0.5
        let center = frame.origin + outerHalfSize
        let cornerRadius = min(
            max(0, cornerRadius),
            min(outerHalfSize.x, outerHalfSize.y)
        )
        let halfSize = outerHalfSize - SIMD2<Float>(repeating: cornerRadius)
        let strokeWidth = max(0, strokeWidth)
        let extent = halfSize + SIMD2<Float>(
            repeating: cornerRadius + strokeWidth * 0.5
        )
        let quadSize = extent * 2

        return ShapeSubmission(
            boundsMinimum: center - extent,
            boundsMaximum: center + extent,
            transformX: .init(quadSize.x, 0),
            transformY: .init(0, quadSize.y),
            transformTranslation: center,
            quadHalfExtent: extent,
            parameters: .init(halfSize.x, halfSize.y, 1, 0),
            fillColor: fill.premultiplied,
            strokeColor: stroke.premultiplied,
            kind: .rectangle,
            strokeWidth: strokeWidth,
            strokeAlignment: 0,
            smoothAntialiasing: 1,
            rounding: cornerRadius,
            blendMode: .premultiplied,
            layer: 0,
            order: 0
        )
    }

    private static func circle(
        frame: Rect,
        fill: PixlGraphics.Color,
        stroke: PixlGraphics.Color,
        strokeWidth: Float
    ) -> ShapeSubmission {
        let radius = min(frame.size.x, frame.size.y) * 0.5
        let center = frame.origin + frame.size * 0.5
        let strokeWidth = max(0, strokeWidth)
        let extent = radius + strokeWidth * 0.5
        let quadSize = extent * 2

        return ShapeSubmission(
            boundsMinimum: center - SIMD2<Float>(repeating: extent),
            boundsMaximum: center + SIMD2<Float>(repeating: extent),
            transformX: .init(quadSize, 0),
            transformY: .init(0, quadSize),
            transformTranslation: center,
            quadHalfExtent: .init(repeating: extent),
            parameters: .init(radius, radius, 0, 0),
            fillColor: fill.premultiplied,
            strokeColor: stroke.premultiplied,
            kind: .circle,
            strokeWidth: strokeWidth,
            strokeAlignment: 0,
            smoothAntialiasing: 1,
            blendMode: .premultiplied,
            layer: 0,
            order: 0
        )
    }

    private static func unevenRoundedRectangle(
        frame: Rect,
        cornerRadii: RectangleCornerRadii,
        fill: PixlGraphics.Color,
        stroke: PixlGraphics.Color,
        strokeWidth: Float
    ) -> ShapeSubmission {
        let halfSize = frame.size * 0.5
        let center = frame.origin + halfSize
        let radii = cornerRadii.normalized(to: frame.size)
        let strokeWidth = max(0, strokeWidth)
        let extent = halfSize + SIMD2<Float>(repeating: strokeWidth * 0.5)
        let quadSize = extent * 2

        return ShapeSubmission(
            boundsMinimum: center - extent,
            boundsMaximum: center + extent,
            transformX: .init(quadSize.x, 0),
            transformY: .init(0, quadSize.y),
            transformTranslation: center,
            quadHalfExtent: extent,
            parameters: .init(
                halfSize.x,
                halfSize.y,
                radii.topLeading,
                radii.topTrailing
            ),
            extendedParameters: .init(
                radii.bottomLeading,
                radii.bottomTrailing,
                0,
                0
            ),
            fillColor: fill.premultiplied,
            strokeColor: stroke.premultiplied,
            kind: .unevenRoundedRectangle,
            strokeWidth: strokeWidth,
            strokeAlignment: 0,
            smoothAntialiasing: 1,
            blendMode: .premultiplied,
            layer: 0,
            order: 0
        )
    }
}

private extension PixlGraphics.Color {
    var premultiplied: SIMD4<Float> {
        .init(red * opacity, green * opacity, blue * opacity, opacity)
    }
}
