import Swift

public enum RenderBatch: Equatable, Sendable {
    case rects(color: Color, rects: [Rect])
    case sprites(textureID: TextureID, sprites: [Sprite])
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
        case .rects(_, let rects):
            rects.count
        case .sprites(_, let sprites):
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
            self = .rects(color: color, rects: [rect])
        case .sprite(let sprite):
            switch sprite.material {
            case .color(let color):
                self = .rects(
                    color: color,
                    rects: [Rect(origin: sprite.position, size: sprite.size)]
                )
            case .sprite(let textureID, sourceRect: _):
                self = .sprites(textureID: textureID, sprites: [sprite])
            }
        }
    }

    private mutating func append(_ primitive: RenderPrimitive) -> Bool {
        switch (self, primitive) {
        case (.rects(let batchColor, var rects), .rect(let rect, let color))
            where batchColor == color:
            rects.append(rect)
            self = .rects(color: batchColor, rects: rects)
            return true

        case (.rects(let batchColor, var rects), .sprite(let sprite)):
            guard case .color(let color) = sprite.material,
                  batchColor == color
            else {
                return false
            }

            rects.append(Rect(origin: sprite.position, size: sprite.size))
            self = .rects(color: batchColor, rects: rects)
            return true

        case (.sprites(let batchTextureID, var sprites), .sprite(let sprite)):
            guard case .sprite(let textureID, sourceRect: _) = sprite.material,
                  batchTextureID == textureID
            else {
                return false
            }

            sprites.append(sprite)
            self = .sprites(textureID: batchTextureID, sprites: sprites)
            return true

        default:
            return false
        }
    }
}
