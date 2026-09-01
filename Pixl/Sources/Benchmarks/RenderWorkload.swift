import PixlFoundation
import PixlPlatform
import Swift

final class RenderWorkload {
    enum Submission {
        case sprite(SpriteSubmission)
        case shape(ShapeSubmission)
        case primitive(PrimitiveSubmission)
    }

    static let submissionCount = 100_000

    let queue = RenderQueue(
        settings: .init(capacity: submissionCount, viewCapacity: 1)
    )
    private let submissions: [Submission]
    private var view = RenderQueue.View(
        projectionX: SIMD3<Float>(0.002, 0, 0),
        projectionY: SIMD3<Float>(0, 0.002, 0),
        projectionTranslation: SIMD3<Float>(-1, -1, 1),
        logicalSize: SIMD2<Float>(1_000, 1_000),
        boundsMinimum: .zero,
        boundsMaximum: SIMD2<Float>(repeating: 1_000)
    )

    init() {
        var random = DeterministicRandom(seed: 0xBADC0FFEE0DDF00D)
        var values: [Submission] = []
        values.reserveCapacity(Self.submissionCount)
        for index in 0..<Self.submissionCount {
            let visible = index % 100 < 10
            let position = visible
                ? SIMD2<Float>(
                    random.float(in: 1...999),
                    random.float(in: 1...999)
                )
                : SIMD2<Float>(
                    random.float(in: 1_200...8_000),
                    random.float(in: 1_200...8_000)
                )
            let halfExtent = SIMD2<Float>(
                random.float(in: 2...16),
                random.float(in: 2...16)
            )
            let layer = UInt32(random.integer(lessThan: 8))
            let order = UInt32(random.integer(lessThan: 4_096))
            switch index % 10 {
            case 0...5:
                values.append(.sprite(Self.makeSprite(
                    position: position,
                    halfExtent: halfExtent,
                    texture: UInt64(index % 4 + 1),
                    layer: layer,
                    order: order
                )))
            case 6...8:
                values.append(.shape(Self.makeShape(
                    position: position,
                    halfExtent: halfExtent,
                    kind: index.isMultiple(of: 2) ? .circle : .rectangle,
                    layer: layer,
                    order: order
                )))
            default:
                values.append(.primitive(Self.makePrimitive(
                    position: position,
                    halfExtent: halfExtent,
                    kind: index.isMultiple(of: 2) ? .rectFill : .ellipseStroke,
                    layer: layer,
                    order: order
                )))
            }
        }
        submissions = values
    }

    func submit() {
        for submission in submissions {
            switch submission {
            case .sprite(let value): queue.submit(value)
            case .shape(let value): queue.submit(value)
            case .primitive(let value): queue.submit(value)
            }
        }
    }

    func execute() -> ExecutionResult {
        defer { queue.reset() }
        return withUnsafePointer(to: &view) { pointer in
            queue.execute(
                views: UnsafeBufferPointer(start: pointer, count: 1)
            ) { execution in
                let output = execution.views[0]
                return ExecutionResult(
                    visibleCount: output.ordinals.count,
                    batchCount: output.batches.count,
                    metrics: execution.metrics
                )
            }
        }
    }

    func correctnessChecksum() -> UInt64 {
        submit()
        defer { queue.reset() }
        return withUnsafePointer(to: &view) { pointer in
            queue.execute(
                views: UnsafeBufferPointer(start: pointer, count: 1)
            ) { execution in
                var checksum = UInt64(execution.instances.count)
                let output = execution.views[0]
                for ordinal in output.ordinals {
                    checksum = mix(checksum, UInt64(ordinal))
                }
                for batch in output.batches {
                    checksum = mix(checksum, UInt64(batch.family.rawValue))
                    checksum = mix(checksum, UInt64(batch.key))
                    checksum = mix(checksum, UInt64(batch.end))
                }
                return checksum
            }
        }
    }

    struct ExecutionResult {
        let visibleCount: Int
        let batchCount: Int
        let metrics: RenderQueue.Metrics
    }

    private static func makeSprite(
        position: SIMD2<Float>,
        halfExtent: SIMD2<Float>,
        texture: UInt64,
        layer: UInt32,
        order: UInt32
    ) -> SpriteSubmission {
        SpriteSubmission(
            boundsMinimum: position - halfExtent,
            boundsMaximum: position + halfExtent,
            texture: TextureResourceID(rawValue: texture),
            textureCoordinateOrigin: .zero,
            textureCoordinateScale: .one,
            transformX: SIMD2<Float>(halfExtent.x, 0),
            transformY: SIMD2<Float>(0, halfExtent.y),
            transformTranslation: position,
            sampler: texture.isMultiple(of: 2)
                ? .init()
                : .init(minFilter: .linear, magFilter: .linear),
            blendMode: texture.isMultiple(of: 3) ? .replace : .normal,
            layer: layer,
            order: order
        )
    }

    private static func makeShape(
        position: SIMD2<Float>,
        halfExtent: SIMD2<Float>,
        kind: ShapeKind,
        layer: UInt32,
        order: UInt32
    ) -> ShapeSubmission {
        ShapeSubmission(
            boundsMinimum: position - halfExtent,
            boundsMaximum: position + halfExtent,
            transformX: SIMD2<Float>(halfExtent.x, 0),
            transformY: SIMD2<Float>(0, halfExtent.y),
            transformTranslation: position,
            quadHalfExtent: .one,
            parameters: SIMD4<Float>(halfExtent.x, halfExtent.y, 0, 0),
            fillColor: SIMD4<Float>(0.25, 0.5, 0.75, 1),
            strokeColor: .zero,
            kind: kind,
            strokeWidth: 0,
            strokeAlignment: 0,
            smoothAntialiasing: 1,
            blendMode: .premultiplied,
            layer: layer,
            order: order
        )
    }

    private static func makePrimitive(
        position: SIMD2<Float>,
        halfExtent: SIMD2<Float>,
        kind: PrimitiveKind,
        layer: UInt32,
        order: UInt32
    ) -> PrimitiveSubmission {
        PrimitiveSubmission(
            boundsMinimum: position - halfExtent,
            boundsMaximum: position + halfExtent,
            transformX: SIMD2<Float>(1, 0),
            transformY: SIMD2<Float>(0, 1),
            transformTranslation: position,
            origin: -halfExtent,
            size: halfExtent * 2,
            color: SIMD4<Float>(0.8, 0.3, 0.1, 1),
            width: 1,
            kind: kind,
            layer: layer,
            order: order
        )
    }
}

private func mix(_ checksum: UInt64, _ value: UInt64) -> UInt64 {
    (checksum ^ value) &* 0x0000_0100_0000_01B3
}
