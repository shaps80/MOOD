import Swift

/// Prepares platform-neutral render data from Pixl game state.
///
/// This renderer does not own GPU resources and does not draw. It resolves
/// shared render semantics so platform renderers cannot diverge on sprite
/// sizing, centering, camera offset, pixel alignment, texture coordinates,
/// colors, or shape packing.
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
    /// - Returns: A prepared frame with camera-adjusted rects, normalized UVs,
    ///   resolved colors, and packed shape values.
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

        let origin = Vec2(
            x: positionedSprite.position.x - game.camera.origin.x - (size.x / 2),
            y: positionedSprite.position.y - game.camera.origin.y - (size.y / 2)
        )
        let rect = Rect(origin: origin, size: size).integral
        let textureRect = TextureRect.normalized(
            sourceRect: sprite.sourceRect,
            textureSize: textureSize
        )
        let color = sprite.resolvedColor(
            fallbackColor: textureSize == nil ? .missingTexture : nil
        )

        return .sprite(
            rect: rect,
            textureRect: textureRect,
            color: color
        )
    }

    private func shapeItem(
        for shape: ShapePrimitive,
        game: Game
    ) -> RenderItem {
        .shape(
            kind: shape.kind.renderItemKind,
            rect: renderRect(for: shape.bounds, game: game),
            radius: shape.radius,
            strokeWidth: shape.strokeWidth,
            lineCap: shape.lineCap.renderValue,
            line: Vec4(
                shape.lineStart.x,
                shape.lineStart.y,
                shape.lineEnd.x,
                shape.lineEnd.y
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

    private func renderRect(for rect: Rect, game: Game) -> Rect {
        Rect(
            origin: Vec2(
                x: rect.origin.x - game.camera.origin.x,
                y: rect.origin.y - game.camera.origin.y
            ),
            size: rect.size
        ).integral
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
