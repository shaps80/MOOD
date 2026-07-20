import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform

extension GameContext {
    /// Renders queued submissions through an orthographic camera after clearing the target.
    ///
    /// ```swift
    /// context.renderQueue.submit(player, transform: .init(position))
    /// try context.render(
    ///     through: camera,
    ///     to: output,
    ///     frame: frame,
    ///     clear: .cornflowerBlue
    /// )
    /// ```
    ///
    /// The queue resets after rendering finishes or throws.
    ///
    /// - Parameters:
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target receiving queued submissions.
    ///   - frame: Frame into which a clearing pass and drawing commands are recorded.
    ///   - color: Colour used to clear `output`. Defaults to opaque black.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        through camera: OrthographicCamera,
        to output: RenderTarget,
        frame: borrowing Frame,
        clear color: PixlGraphics.Color = .init(0, 0, 0, 1)
    ) throws {
        let pass = frame.clear(color, target: output)
        try render(through: camera, to: output, on: pass)
    }

    /// Renders queued submissions through an orthographic camera into an existing pass.
    ///
    /// The pass's existing load action is preserved. The queue resets after rendering
    /// finishes or throws.
    ///
    /// - Parameters:
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target whose dimensions determine the camera aspect ratio.
    ///   - pass: Existing encoder that receives drawing commands.
    /// - Throws: An error encountered while resolving resources or recording commands.
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
        let encodingMetrics = try withUnsafePointer(to: &view) { pointer in
            try renderQueue.execute(
                views: UnsafeBufferPointer(start: pointer, count: 1)
            ) { execution in
                try spriteRenderWorkspace.encode(
                    execution,
                    viewIndex: 0,
                    on: pass
                )
            }
        }
        var metrics = renderQueue.latestMetrics
        metrics.instancesSeconds += encodingMetrics.instancesSeconds
        record(metrics)
    }
}
