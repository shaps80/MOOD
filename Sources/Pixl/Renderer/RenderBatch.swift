import Swift

public enum RenderBatch: Equatable, Sendable {
    case sprites(textureID: TextureID, blendMode: BlendMode, sprites: [Sprite])
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
        case .sprite(let sprite):
            switch sprite.material {
            case .sprite(let textureID, sourceRect: _):
                self = .sprites(
                    textureID: textureID,
                    blendMode: sprite.blendMode,
                    sprites: [sprite]
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
        case (.sprites(let batchTextureID, let blendMode, var sprites), .sprite(let sprite)):
            guard case .sprite(let textureID, sourceRect: _) = sprite.material,
                  batchTextureID == textureID,
                  blendMode == sprite.blendMode
            else {
                return false
            }

            sprites.append(sprite)
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
