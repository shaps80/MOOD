import Pixl
import Pixl2D

struct WorldBounds: Entity {
    private let shape = Shape(.rect).fill(.gray6)
    private var slope = Polygon(
        triangle: .init(800, 20),
        paint: .color(.blue)
    )

    private let rendering = RenderProperties(layer: .environment)

    let floor = Rect(
        x: -400,
        y: -200,
        width: 800,
        height: 20
    )

    let leftWall = Rect(
        x: -400,
        y: -200,
        width: 20,
        height: 400
    )

    let rightWall = Rect(
        x: 380,
        y: -200,
        width: 20,
        height: 400
    )

    var slopeGeometry: Polygon2D { slope.geometry }

    var slopeTransform: Transform2D {
        .init(floor.center).scaled(x: -1, y: 1)
    }

    func submit(to queue: RenderQueue, context: GameContext) {
        submit(leftWall, to: queue)
        submit(rightWall, to: queue)

        queue.submit(
            slope,
            transform: slopeTransform,
            rendering: rendering
        )
    }

    private func submit(_ bounds: Rect, to queue: RenderQueue) {
        queue.submit(
            shape,
            transform: .init(bounds.center, scale: bounds.size),
            rendering: rendering
        )
    }
}
