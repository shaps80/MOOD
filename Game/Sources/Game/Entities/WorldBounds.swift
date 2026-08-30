import Pixl
import Pixl2D

struct WorldBounds: Entity {
    private let shape = Shape(.rect).fill(.gray6)
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

    func submit(to queue: RenderQueue, context: GameContext) {
        submit(floor, to: queue)
        submit(leftWall, to: queue)
        submit(rightWall, to: queue)
    }

    private func submit(_ bounds: Rect, to queue: RenderQueue) {
        queue.submit(
            shape,
            transform: Transform2D(bounds.center, scale: bounds.size),
            rendering: rendering
        )
    }
}
