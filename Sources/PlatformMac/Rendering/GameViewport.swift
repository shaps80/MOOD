@preconcurrency import Metal
import Pixl
import Swift

struct GameViewport {
    let metalViewport: MTLViewport

    init(
        drawableSize: CGSize,
        gameSize: Vec2
    ) {
        let viewport = PresentationViewport(
            containerSize: Vec2(
                x: Double(drawableSize.width),
                y: Double(drawableSize.height)
            ),
            logicalResolution: gameSize
        )

        self.metalViewport = MTLViewport(
            originX: viewport.rect.origin.x,
            originY: viewport.rect.origin.y,
            width: viewport.rect.size.x,
            height: viewport.rect.size.y,
            znear: 0,
            zfar: 1
        )
    }
}
