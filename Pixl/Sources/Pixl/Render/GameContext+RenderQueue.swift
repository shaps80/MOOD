import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform
import PixlUI

extension GameContext {
    /// Clears a render target to one colour.
    public func clear(
        target output: RenderTarget,
        color: PixlGraphics.Color = .black,
        frame: borrowing Frame
    ) {
        guard color.opacity != 0 else { return }
        _ = frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: output,
                    loadAction: .clear(color.rgba)
                )
            )
        )
    }

    /// Clears a context-owned render texture to one colour.
    public func clear(
        target output: RenderTexture,
        color: PixlGraphics.Color = .black,
        frame: borrowing Frame
    ) {
        guard color.opacity != 0 else { return }
        guard let texture = assets.texture(for: output.texture) else {
            preconditionFailure("Render texture does not belong to this game context")
        }
        clear(target: .init(texture: texture), color: color, frame: frame)
    }

    /// Renders a retained UI scene in logical screen-space coordinates.
    ///
    /// Existing target contents are preserved. Repeated calls compose in call
    /// order, allowing game rendering before, between, or after UI scenes.
    public func render<Content: View>(
        scene: Scene<Content>,
        to output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        let scale = displayScale
        let pixels = output.texture.descriptor.size
        precondition(
            pixels.width > 0 && pixels.height > 0,
            "UI render target dimensions must be greater than zero"
        )
        let logicalSize = Size(
            x: Float(pixels.width) / scale,
            y: Float(pixels.height) / scale
        )
        var compilation = try compilation(
            for: scene,
            size: logicalSize,
            displayScale: scale
        )
        if shouldDispatchInput(for: scene) {
            compilation.dispatchInputs()
            compilation = try self.compilation(
                for: scene,
                size: logicalSize,
                displayScale: scale
            )
        }

        compilation.submissions.withUnsafeBufferPointer {
            sceneRenderQueue.submit(contentsOf: $0)
        }
        try render(queue: sceneRenderQueue, to: output, frame: frame)
    }

    /// Renders screen-space submissions into a presentation target.
    ///
    /// The origin is top-left, positive y points down, and target contents are preserved.
    public func render(
        _ screenSpace: ScreenSpace,
        to output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        precondition(screenSpace.context === self, "ScreenSpace belongs to another game context")
        try render(queue: renderQueue, to: output, frame: frame)
    }

    /// Renders one queue in logical screen-space coordinates.
    ///
    /// The origin is top-left, positive y points down, and target contents are
    /// preserved. The queue resets after rendering finishes or throws.
    private func render(
        queue: RenderQueue,
        to output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        let pass = beginPass(on: output, frame: frame)
        try render(queue: queue, to: output, on: pass)
    }

    /// Renders screen-space submissions into a render texture.
    public func render(
        _ screenSpace: ScreenSpace,
        to output: RenderTexture,
        frame: borrowing Frame
    ) throws {
        precondition(screenSpace.context === self, "ScreenSpace belongs to another game context")
        try render(queue: renderQueue, to: output, frame: frame)
    }

    /// Renders one queue in logical screen space into a render texture.
    private func render(
        queue: RenderQueue,
        to output: RenderTexture,
        frame: borrowing Frame
    ) throws {
        guard let texture = assets.texture(for: output.texture) else {
            preconditionFailure("Render texture does not belong to this game context")
        }
        try render(
            queue: queue,
            to: RenderTarget(texture: texture),
            frame: frame
        )
    }

    /// Renders screen-space submissions into an existing pass.
    public func render(
        _ screenSpace: ScreenSpace,
        to output: RenderTarget,
        on pass: RenderPassEncoder
    ) throws {
        precondition(screenSpace.context === self, "ScreenSpace belongs to another game context")
        try render(queue: renderQueue, to: output, on: pass)
    }

    /// Renders one queue in logical screen space into an existing pass.
    private func render(
        queue: RenderQueue,
        to output: RenderTarget,
        on pass: RenderPassEncoder
    ) throws {
        defer { queue.reset() }
        let workspace = workspace(for: queue)
        let pixels = output.texture.descriptor.size
        precondition(
            pixels.width > 0 && pixels.height > 0,
            "Screen-space render target dimensions must be greater than zero"
        )
        let logicalSize = Size(
            x: Float(pixels.width) / displayScale,
            y: Float(pixels.height) / displayScale
        )
        var view = RenderQueue.View(
            projectionX: .init(2 / logicalSize.width, 0, 0),
            projectionY: .init(0, -2 / logicalSize.height, 0),
            projectionTranslation: .init(-1, 1, 1),
            boundsMinimum: .zero,
            boundsMaximum: logicalSize
        )
        let encodingMetrics = try withUnsafePointer(to: &view) { pointer in
            try queue.execute(
                views: UnsafeBufferPointer(start: pointer, count: 1)
            ) { execution in
                try workspace.encode(execution, viewIndex: 0, on: pass)
            }
        }
        var metrics = queue.latestMetrics
        metrics.instancesSeconds += encodingMetrics.instancesSeconds
        record(metrics)
    }

    /// Renders the default queue through a 2D camera while preserving the target.
    ///
    /// ```swift
    /// context.renderQueue.submit(player, transform: .init(position))
    /// try context.render(
    ///     through: camera,
    ///     to: output,
    ///     frame: frame
    /// )
    /// ```
    ///
    /// The default queue resets after rendering finishes or throws.
    ///
    /// - Parameters:
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target receiving queued submissions.
    ///   - frame: Frame into which drawing commands are recorded.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        through camera: some Camera2D,
        to output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        try render(
            queue: renderQueue,
            through: camera,
            to: output,
            frame: frame
        )
    }

    /// Renders one queue through a 2D camera into a render target.
    ///
    /// The queue resets after rendering finishes or throws.
    ///
    /// - Parameters:
    ///   - queue: Submission queue to consume.
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Render target receiving queued submissions.
    ///   - frame: Frame receiving the render pass and drawing commands.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        queue: RenderQueue,
        through camera: some Camera2D,
        to output: RenderTarget,
        frame: borrowing Frame
    ) throws {
        let pass = beginPass(
            on: output,
            frame: frame
        )

        try render(
            queue: queue,
            through: camera,
            to: output,
            on: pass
        )
    }

    /// Renders the default queue into a context-owned render texture while preserving it.
    ///
    /// The default queue resets after rendering finishes or throws. `output`
    /// must have been created with this context.
    ///
    /// - Parameters:
    ///   - camera: Camera defining projection and visible world-space bounds.
    ///   - output: Context-owned render texture receiving queued submissions.
    ///   - frame: Frame into which drawing commands are recorded.
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        through camera: some Camera2D,
        to output: RenderTexture,
        frame: borrowing Frame
    ) throws {
        try render(
            queue: renderQueue,
            through: camera,
            to: output,
            frame: frame
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
    /// - Throws: An error encountered while resolving resources or recording commands.
    public func render(
        queue: RenderQueue,
        through camera: some Camera2D,
        to output: RenderTexture,
        frame: borrowing Frame
    ) throws {
        guard let texture = assets.texture(for: output.texture) else {
            preconditionFailure("Render texture does not belong to this game context")
        }
        try render(
            queue: queue,
            through: camera,
            to: RenderTarget(texture: texture),
            frame: frame
        )
    }

    /// Renders the default queue through a 2D camera into an existing pass.
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
        through camera: some Camera2D,
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

    /// Renders one queue through a 2D camera into an existing pass.
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
        through camera: some Camera2D,
        to output: RenderTarget,
        on pass: RenderPassEncoder
    ) throws {
        defer { queue.reset() }
        let workspace = workspace(for: queue)
        let size = output.texture.descriptor.size
        let presentationSize = Vec2(
            Float(size.width),
            Float(size.height)
        )
        let projection = camera.projection(in: presentationSize)
        let boundsMinimum: Vec2
        let boundsMaximum: Vec2
        if let inverseProjection = projection.inverted {
            let visibleBounds = inverseProjection.transformed(
                bounds: .init(x: -1, y: -1, width: 2, height: 2)
            )
            boundsMinimum = visibleBounds.origin
            boundsMaximum = visibleBounds.origin + visibleBounds.size
        } else {
            boundsMinimum = .init(repeating: -.infinity)
            boundsMaximum = .init(repeating: .infinity)
        }
        var view = RenderQueue.View(
            projectionX: projection.x,
            projectionY: projection.y,
            projectionTranslation: projection.translation,
            boundsMinimum: boundsMinimum,
            boundsMaximum: boundsMaximum
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
        frame: borrowing Frame
    ) -> RenderPassEncoder {
        return frame.beginRenderPass(
            RenderPassDescriptor(
                ColorAttachment(
                    target: output,
                    loadAction: .load
                )
            )
        )
    }

}
