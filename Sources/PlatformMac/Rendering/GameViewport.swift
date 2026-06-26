@preconcurrency import Metal
import GameCore
import Swift

struct GameViewport {
    let metalViewport: MTLViewport

    init(
        drawableSize: CGSize,
        gameSize: Vec2
    ) {
        let scale = Self.displayScale(
            drawableSize: drawableSize,
            gameSize: gameSize
        )
        let width = gameSize.x * scale
        let height = gameSize.y * scale
        let x = (drawableSize.width - width) / 2
        let y = (drawableSize.height - height) / 2

        self.metalViewport = MTLViewport(
            originX: x,
            originY: y,
            width: width,
            height: height,
            znear: 0,
            zfar: 1
        )
    }

    private static func displayScale(
        drawableSize: CGSize,
        gameSize: Vec2
    ) -> Double {
        min(
            drawableSize.width / gameSize.x,
            drawableSize.height / gameSize.y
        )
    }
}
