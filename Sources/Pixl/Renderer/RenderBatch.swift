import Swift

public enum RenderBatch: Equatable, Sendable {
    case solids(blendMode: BlendMode, sprites: [Sprite])
    case sprites(textureID: TextureID, blendMode: BlendMode, sprites: [Sprite])
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
        case .solids(_, let sprites),
             .sprites(_, _, let sprites):
            sprites.count
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
        case .rect(let rect, let color):
            self = .solids(
                blendMode: .normal,
                sprites: [
                    Sprite(
                        position: rect.origin,
                        size: rect.size,
                        material: .color(color)
                    )
                ]
            )
        case .sprite(let sprite):
            switch sprite.material {
            case .color:
                self = .solids(
                    blendMode: sprite.blendMode,
                    sprites: [sprite]
                )
            case .sprite(let textureID, sourceRect: _):
                self = .sprites(
                    textureID: textureID,
                    blendMode: sprite.blendMode,
                    sprites: [sprite]
                )
            }
        }
    }

    private mutating func append(_ primitive: RenderPrimitive) -> Bool {
        switch (self, primitive) {
        case (.solids(let blendMode, var sprites), .rect(let rect, let color))
            where blendMode == .normal:
            sprites.append(
                Sprite(
                    position: rect.origin,
                    size: rect.size,
                    material: .color(color)
                )
            )
            self = .solids(blendMode: blendMode, sprites: sprites)
            return true

        case (.solids(let blendMode, var sprites), .sprite(let sprite)):
            guard case .color = sprite.material,
                  blendMode == sprite.blendMode
            else {
                return false
            }

            sprites.append(sprite)
            self = .solids(blendMode: blendMode, sprites: sprites)
            return true

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

        default:
            return false
        }
    }
}
