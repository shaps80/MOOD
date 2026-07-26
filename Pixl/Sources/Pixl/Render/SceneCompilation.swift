import PixlFoundation
import PixlGraphics
import PixlPlatform
import PixlUI

final class SceneCompilation {
    weak var scene: AnyObject?
    let generation: UInt64
    let size: Size
    let displayScale: Float
    let submissions: ContiguousArray<ShapeSubmission>

    init<Content: View>(
        scene: Scene<Content>,
        size: Size,
        displayScale: Float
    ) {
        let prepared = scene.prepare(size: size, displayScale: displayScale)
        self.scene = scene
        generation = scene.generation
        self.size = size
        self.displayScale = displayScale
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

    private static func lower(
        graph: ViewGraph,
        layout: ViewLayout
    ) -> ContiguousArray<ShapeSubmission> {
        var submissions: ContiguousArray<ShapeSubmission> = []
        submissions.reserveCapacity(graph.primitives.count + graph.shapes.count)

        for (index, node) in graph.nodes.enumerated() {
            let frame = layout.frames[index]
            guard frame.size.width > 0, frame.size.height > 0 else { continue }

            switch node.kind {
            case .primitive:
                guard case .fill(let style) = graph.primitives[Int(node.payload)] else {
                    continue
                }
                submissions.append(
                    rectangle(
                        frame: frame,
                        fill: color(for: style, in: graph),
                        stroke: .clear,
                        strokeWidth: 0
                    )
                )

            case .shape:
                let shape = graph.shapes[Int(node.payload)]
                switch shape.shape.path(in: frame) {
                case .rectangle(let rect):
                    submissions.append(
                        rectangle(
                            frame: rect,
                            fill: color(for: shape.fill, in: graph),
                            stroke: shape.stroke.map {
                                color(for: $0.style, in: graph)
                            } ?? .clear,
                            strokeWidth: shape.stroke?.lineWidth ?? 0
                        )
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
        strokeWidth: Float
    ) -> ShapeSubmission {
        let halfSize = frame.size * 0.5
        let center = frame.origin + halfSize
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
            parameters: .init(halfSize.x, halfSize.y, 0, 0),
            fillColor: fill.premultiplied,
            strokeColor: stroke.premultiplied,
            kind: .rectangle,
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
