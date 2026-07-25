import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform

extension GameContext {
    /// Renders the default queue through an orthographic camera after clearing the target.
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
    /// The default queue resets after rendering finishes or throws.
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
        clear color: PixlGraphics.Color = .black
    ) throws {
        try render(
            queue: renderQueue,
            through: camera,
            to: output,
            frame: frame,
            initialState: .clear(color)
        )
    }

    /// Renders one queue through an orthographic camera into a render target.
    ///
    /// The queue resets after rendering finishes or throws.
    ///
    /// - Parameters:
    ///   - queue: Submission queue to consume.
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target receiving queued submissions.
    ///   - frame: Frame receiving the render pass and drawing commands.
    ///   - initialState: Whether rendering clears or preserves existing contents.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        queue: RenderQueue,
        through camera: OrthographicCamera,
        to output: RenderTarget,
        frame: borrowing Frame,
        initialState: RenderInitialState
    ) throws {
        let pass = beginPass(
            on: output,
            frame: frame,
            initialState: initialState
        )

        try render(
            queue: queue,
            through: camera,
            to: output,
            on: pass
        )
    }

    /// Renders the default queue into a context-owned render texture after clearing it.
    ///
    /// The default queue resets after rendering finishes or throws. `output`
    /// must have been created with this context.
    ///
    /// - Parameters:
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Context-owned render texture receiving queued submissions.
    ///   - frame: Frame into which a clearing pass and drawing commands are recorded.
    ///   - color: Colour used to clear `output`. Defaults to opaque black.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        through camera: OrthographicCamera,
        to output: RenderTexture,
        frame: borrowing Frame,
        clear color: PixlGraphics.Color = .black
    ) throws {
        try render(
            queue: renderQueue,
            through: camera,
            to: output,
            frame: frame,
            initialState: .clear(color)
        )
    }

    /// Renders one queue into a context-owned render texture.
    ///
    /// The queue resets after rendering finishes or throws. `output` must have
    /// been created with this context.
    ///
    /// - Parameters:
    ///   - queue: Submission queue to consume.
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Context-owned render texture receiving queued submissions.
    ///   - frame: Frame receiving the render pass and drawing commands.
    ///   - initialState: Whether rendering clears or preserves existing contents.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        queue: RenderQueue,
        through camera: OrthographicCamera,
        to output: RenderTexture,
        frame: borrowing Frame,
        initialState: RenderInitialState
    ) throws {
        guard let texture = assets.texture(for: output.texture) else {
            preconditionFailure("Render texture does not belong to this game context")
        }
        try render(
            queue: queue,
            through: camera,
            to: RenderTarget(texture: texture),
            frame: frame,
            initialState: initialState
        )
    }

    /// Renders the default queue through an orthographic camera into an existing pass.
    ///
    /// The pass's existing load action is preserved. The default queue resets
    /// after rendering finishes or throws.
    ///
    /// - Parameters:
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target whose dimensions determine the camera aspect ratio.
    ///   - pass: Existing encoder receiving drawing commands.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        through camera: OrthographicCamera,
        to output: RenderTarget,
        on pass: RenderPassEncoder
    ) throws {
        try render(
            queue: renderQueue,
            through: camera,
            to: output,
            on: pass
        )
    }

    /// Renders one queue through an orthographic camera into an existing pass.
    ///
    /// The pass's existing load action is preserved. The queue resets after
    /// rendering finishes or throws.
    ///
    /// - Parameters:
    ///   - queue: Submission queue to consume.
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target whose dimensions determine the camera aspect ratio.
    ///   - pass: Existing encoder receiving drawing commands.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        queue: RenderQueue,
        through camera: OrthographicCamera,
        to output: RenderTarget,
        on pass: RenderPassEncoder
    ) throws {
        defer { queue.reset() }
        let workspace = workspace(for: queue)
        let size = output.texture.descriptor.size
        let aspect = Float(size.width) / Float(size.height)
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
            try queue.execute(
                views: UnsafeBufferPointer(start: pointer, count: 1)
            ) { execution in
                try workspace.encode(
                    execution,
                    viewIndex: 0,
                    on: pass
                )
            }
        }
        var metrics = queue.latestMetrics
        metrics.instancesSeconds += encodingMetrics.instancesSeconds
        record(metrics)
    }

    private func beginPass(
        on output: RenderTarget,
        frame: borrowing Frame,
        initialState: RenderInitialState
    ) -> RenderPassEncoder {
        let loadAction: LoadAction
        switch initialState {
        case .clear(let color):
            loadAction = .clear(color.rgba)
        case .preserve:
            loadAction = .load
        }
        return frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: output,
                    loadAction: loadAction
                )
            )
        )
    }
}
