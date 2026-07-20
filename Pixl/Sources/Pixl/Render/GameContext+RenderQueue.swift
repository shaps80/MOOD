import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform

extension GameContext {
    public func render(
        through camera: OrthographicCamera,
        to output: RenderTarget,
        frame: borrowing Frame,
        clear color: PixlGraphics.Color = .init(0, 0, 0, 1)
    ) throws {
        let pass = frame.clear(color, target: output)
        try render(through: camera, to: output, on: pass)
    }

    public func render(
        through camera: OrthographicCamera,
        to output: RenderTarget,
        on pass: RenderPassEncoder
    ) throws {
        defer { renderQueue.reset() }
        let size = output.texture.descriptor.size
        let aspect = Double(size.width) / Double(size.height)
        let halfWidth = camera.halfHeight * aspect
        let projection = camera.projection(aspectRatio: aspect)
        var view = RenderQueue.View(
            projectionX: projection.x,
            projectionY: projection.y,
            projectionTranslation: projection.translation,
            boundsMinimum: .init(
                Float(camera.center.x - halfWidth),
                Float(camera.center.y - camera.halfHeight)
            ),
            boundsMaximum: .init(
                Float(camera.center.x + halfWidth),
                Float(camera.center.y + camera.halfHeight)
            )
        )
        try withUnsafePointer(to: &view) { pointer in
            try renderQueue.execute(
                views: UnsafeBufferPointer(start: pointer, count: 1)
            ) { execution in
                try spriteRenderResources.encode(
                    execution,
                    viewIndex: 0,
                    queue: renderQueue,
                    on: pass
                )
            }
        }
        record(renderQueue.latestMetrics)
    }
}
