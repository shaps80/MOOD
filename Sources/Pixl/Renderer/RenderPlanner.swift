import Swift

/// Prepares platform-neutral render data from Pixl game state.
///
/// This renderer does not own GPU resources and does not draw. It resolves
/// shared render semantics so platform renderers cannot diverge on sprite
/// sizing, centering, camera offset, rotation, pixel alignment, texture
/// coordinates, colors, or shape packing.
///
/// ```swift
/// var planner = RenderPlanner()
/// let frame = planner.prepareFrame(
///     game: game,
///     textureSizes: loadedTextureSizes
/// )
/// ```
public struct RenderPlanner: Sendable {
    /// Creates an empty render planner.
    public init() {}

    /// Converts a game's render batches into platform-uploadable frame data.
    ///
    /// - Parameters:
    ///   - game: The game state containing sorted render batches.
    ///   - textureSizes: Loaded texture sizes keyed by texture ID. Platforms
    ///     provide this because only they know the real loaded texture size.
    /// - Returns: A prepared frame with camera-adjusted transforms, normalized
    ///   UVs, resolved colors, and packed shape values.
    public mutating func prepareFrame(
        game: Game,
        textureSizes: [TextureID: Vec2]
    ) -> RenderFrame {
        var batches: [PreparedRenderBatch] = []
        batches.reserveCapacity(game.renderStats.batchCount)

        for batch in game.renderBatches {
            switch batch {
            case .items(let textureID, let blendMode, let primitives):
                let items = primitives.compactMap {
                    item(for: $0, game: game, textureSizes: textureSizes)
                }

                guard !items.isEmpty else { continue }
                batches.append(
                    .items(
                        textureID: textureID,
                        blendMode: blendMode,
                        items: items
                    )
                )
            }
        }

        return RenderFrame(batches: batches)
    }

    private func item(
        for primitive: RenderPrimitive,
        game: Game,
        textureSizes: [TextureID: Vec2]
    ) -> RenderItem? {
        switch primitive {
        case .sprite(let positionedSprite):
            guard case .sprite(let textureID, sourceRect: _) = positionedSprite.sprite.material else {
                preconditionFailure("Shape sprites must expand before render planning.")
            }

            return spriteItem(
                for: positionedSprite,
                textureID: textureID,
                game: game,
                textureSizes: textureSizes
            )
        case .shape(let shape):
            return shapeItem(for: shape, game: game)
        }
    }

    private func spriteItem(
        for positionedSprite: PositionedSprite,
        textureID: TextureID,
        game: Game,
        textureSizes: [TextureID: Vec2]
    ) -> RenderItem? {
        let sprite = positionedSprite.sprite
        let textureSize = textureSizes[textureID]
        let size = sprite.renderedSize(textureSize: textureSize)

        guard size.x > 0, size.y > 0 else {
            return nil
        }

        let transform = RenderTransform(
            center: positionedSprite.position,
            size: size,
            rotation: positionedSprite.transform.rotation
        ).applyingCamera(game)
        let rect = transform.rect.integral
        let alignedTransform = RenderTransform(
            center: rect.center,
            size: rect.size,
            rotation: transform.rotation
        )
        let textureRect = TextureRect.normalized(
            sourceRect: sprite.sourceRect,
            textureSize: textureSize
        )
        let color = sprite.resolvedColor(
            fallbackColor: textureSize == nil ? .missingTexture : nil
        )

        return .sprite(
            transform: alignedTransform,
            textureRect: textureRect,
            color: color
        )
    }

    private func shapeItem(
        for shape: ShapePrimitive,
        game: Game
    ) -> RenderItem {
        let transform = renderTransform(
            for: shape.bounds,
            rotation: shape.rotation,
            game: game
        )
        let cameraScale = game.cameraTransform.scale
        let scalarScale = (cameraScale.x.magnitude + cameraScale.y.magnitude) / 2

        return .shape(
            kind: shape.kind.renderItemKind,
            transform: transform,
            radius: shape.radius * scalarScale,
            strokeWidth: shape.strokeWidth * scalarScale,
            lineCap: shape.lineCap.renderValue,
            line: Vec4(
                shape.lineStart.x * cameraScale.x,
                shape.lineStart.y * cameraScale.y,
                shape.lineEnd.x * cameraScale.x,
                shape.lineEnd.y * cameraScale.y
            ),
            fillColor: shape.fillColor,
            strokeColor: shape.strokeColor,
            flags: Vec4(
                shape.fillAntialiased ? 1 : 0,
                shape.strokeAntialiased ? 1 : 0,
                shape.cornerStyle.renderValue,
                0
            )
        )
    }

    private func renderTransform(
        for rect: Rect,
        rotation: Angle,
        game: Game
    ) -> RenderTransform {
        let transform = RenderTransform(
            center: rect.center,
            size: rect.size,
            rotation: rotation
        ).applyingCamera(game)
        let rect = transform.rect.integral

        return RenderTransform(
            center: rect.center,
            size: rect.size,
            rotation: transform.rotation
        )
    }
}

private extension RenderTransform {
    func applyingCamera(_ game: Game) -> RenderTransform {
        let camera = game.camera
        let cameraTransform = game.cameraTransform
        let viewportCenter = camera.viewportSize * 0.5
        let localCenter = center - camera.origin - viewportCenter
        let transformedCenter = viewportCenter
            + (localCenter * cameraTransform.scale).rotated(by: cameraTransform.rotation)
            + cameraTransform.position

        return RenderTransform(
            center: transformedCenter,
            size: size * cameraTransform.scale,
            rotation: rotation + cameraTransform.rotation
        )
    }
}

private extension Vec2 {
    func rotated(by rotation: Angle) -> Vec2 {
        let components = sincos(rotation)

        return Vec2(
            x: (x * components.cos) - (y * components.sin),
            y: (x * components.sin) + (y * components.cos)
        )
    }
}

private extension ShapePrimitiveKind {
    var renderItemKind: RenderItemKind {
        switch self {
        case .rect:
            return .rect
        case .roundedRect:
            return .roundedRect
        case .ellipse:
            return .ellipse
        case .line:
            return .line
        }
    }
}
