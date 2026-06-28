import Swift

public enum RenderBatch: Equatable, Sendable {
    case sprites(textureID: TextureID, blendMode: BlendMode, sprites: [PositionedSprite])
    case shapes(blendMode: BlendMode, shapes: [ShapePrimitive])
}

public extension RenderBatch {
    static func make(from commands: [RenderCommand]) -> [RenderBatch] {
        var batches: [RenderBatch] = []

        for command in commands {
            command.forEachPrimitive { primitive in
                append(primitive, to: &batches)
            }
        }

        return batches
    }

    var primitiveCount: Int {
        switch self {
        case .sprites(_, _, let sprites):
            sprites.count
        case .shapes(_, let shapes):
            shapes.count
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
        switch primitive {
        case .sprite(let positionedSprite):
            switch positionedSprite.sprite.material {
            case .sprite(let textureID, sourceRect: _):
                self = .sprites(
                    textureID: textureID,
                    blendMode: positionedSprite.sprite.blendMode,
                    sprites: [positionedSprite]
                )
            case .shape:
                preconditionFailure("Shape sprites must expand before batching.")
            }
        case .shape(let shape):
            self = .shapes(blendMode: shape.blendMode, shapes: [shape])
        }
    }

    private mutating func append(_ primitive: RenderPrimitive) -> Bool {
        switch (self, primitive) {
        case (.sprites(let batchTextureID, let blendMode, var sprites), .sprite(let positionedSprite)):
            guard case .sprite(let textureID, sourceRect: _) = positionedSprite.sprite.material,
                  batchTextureID == textureID,
                  blendMode == positionedSprite.sprite.blendMode
            else {
                return false
            }

            sprites.append(positionedSprite)
            self = .sprites(
                textureID: batchTextureID,
                blendMode: blendMode,
                sprites: sprites
            )
            return true

        case (.shapes(let blendMode, var shapes), .shape(let shape))
            where blendMode == shape.blendMode:
            shapes.append(shape)
            self = .shapes(blendMode: blendMode, shapes: shapes)
            return true

        default:
            return false
        }
    }
}
