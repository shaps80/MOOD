import Pixl
import Pixl2D

struct WorldBounds: Entity {
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
        context.draw(
            .rect(floor),
            style: .fill(.gray3),
            layer: .environment
        )
        context.draw(
            .rect(leftWall),
            style: .fill(.gray3),
            layer: .environment
        )
        context.draw(
            .rect(rightWall),
            style: .fill(.gray3),
            layer: .environment
        )
    }
}
