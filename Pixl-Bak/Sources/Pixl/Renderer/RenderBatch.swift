import Swift

/// A coarse platform-neutral batch built from sorted render commands.
///
/// `RenderBatch` groups adjacent primitives that can be prepared together.
/// `RenderPlanner` later converts these into upload-ready `PreparedRenderBatch`
/// values.
public enum RenderBatch: Equatable, Sendable {
    /// Adjacent render primitives sharing a blend mode and compatible texture binding.
    case items(textureID: TextureID?, blendMode: BlendMode, primitives: [RenderPrimitive])
}

public extension RenderBatch {
    /// Builds render batches from commands while preserving command order.
    ///
    /// ```swift
    /// let batches = RenderBatch.make(from: context.commands)
    /// ```
    static func make(from commands: [RenderCommand]) -> [RenderBatch] {
        var batches: [RenderBatch] = []

        for command in commands {
            command.forEachPrimitive { primitive in
                append(primitive, to: &batches)
            }
        }

        return batches
    }

    /// Number of primitives contained in this batch.
    var primitiveCount: Int {
        switch self {
        case .items(_, _, let primitives):
            primitives.count
        }
    }

    private static func append(
        _ primitive: RenderPrimitive,
        to batches: inout [RenderBatch]
    ) {
        guard let lastIndex = batches.indices.last,
              batches[lastIndex].append(primitive)
        else {
            batches.append(RenderBatch(primitive))
            return
        }
    }

    private init(_ primitive: RenderPrimitive) {
        self = .items(
            textureID: primitive.textureID,
            blendMode: primitive.blendMode,
            primitives: [primitive]
        )
    }

    private mutating func append(_ primitive: RenderPrimitive) -> Bool {
        switch self {
        case .items(let batchTextureID, let blendMode, var primitives):
            guard blendMode == primitive.blendMode else {
                return false
            }

            let primitiveTextureID = primitive.textureID
            let textureID: TextureID?

            if let batchTextureID, let primitiveTextureID, batchTextureID != primitiveTextureID {
                return false
            } else {
                textureID = batchTextureID ?? primitiveTextureID
            }

            primitives.append(primitive)
            self = .items(
                textureID: textureID,
                blendMode: blendMode,
                primitives: primitives
            )
            return true
        }
    }
}

private extension RenderPrimitive {
    var textureID: TextureID? {
        switch self {
        case .sprite(let positionedSprite):
            switch positionedSprite.sprite.material {
            case .sprite(let textureID, sourceRect: _):
                return textureID
            case .shape:
                preconditionFailure("Shape sprites must expand before batching.")
            }
        case .shape:
            return nil
        }
    }

    var blendMode: BlendMode {
        switch self {
        case .sprite(let positionedSprite):
            return positionedSprite.sprite.blendMode
        case .shape(let shape):
            return shape.blendMode
        }
    }
}
