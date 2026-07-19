import Pixl2D
import PixlGraphics
import PixlPlatform

private struct PrimitiveParameters: BitwiseCopyable {
    let transform: Transform2D
    let textureCoordinates: TextureCoordinates
}

/// Temporary GPU-backed unit quad used by the built-in sprite renderer.
/// Foundation-level geometry and instance storage will replace this type.
struct Quad: Sendable {
    private let vertexBuffer: Buffer
    private let indexBuffer: Buffer

    init(
        device: any Device,
        colors: (
            PixlGraphics.Color,
            PixlGraphics.Color,
            PixlGraphics.Color,
            PixlGraphics.Color
        ) = (
            .init(1, 1, 0, 1),
            .init(0, 1, 1, 1),
            .init(1, 0, 1, 1),
            .init(1, 1, 1, 1)
        )
    ) throws {
        var vertices = (
            PrimitiveVertex.make(
                position: .init(-0.5, 0.5),
                color: colors.0,
                textureCoordinate: .init(0, 0)
            ),
            PrimitiveVertex.make(
                position: .init(-0.5, -0.5),
                color: colors.1,
                textureCoordinate: .init(0, 1)
            ),
            PrimitiveVertex.make(
                position: .init(0.5, -0.5),
                color: colors.2,
                textureCoordinate: .init(1, 1)
            ),
            PrimitiveVertex.make(
                position: .init(0.5, 0.5),
                color: colors.3,
                textureCoordinate: .init(1, 0)
            )
        )
        var indices: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) = (
            0, 1, 2, 0, 2, 3
        )

        vertexBuffer = try withUnsafeBytes(of: &vertices) {
            try device.makeBuffer(copying: $0, usage: .vertex, memory: .gpuOnly)
        }
        indexBuffer = try withUnsafeBytes(of: &indices) {
            try device.makeBuffer(copying: $0, usage: .index, memory: .gpuOnly)
        }
    }

    init(device: any Device, color: PixlGraphics.Color) throws {
        try self.init(device: device, colors: (color, color, color, color))
    }

    func draw(on pass: RenderPassEncoder, transform: Transform2D) {
        draw(
            on: pass,
            transform: transform,
            textureCoordinates: .init()
        )
    }

    func draw(
        on pass: RenderPassEncoder,
        transform: Transform2D,
        textureCoordinates: TextureCoordinates
    ) {
        pass.setVertexBytes(
            of: PrimitiveParameters(
                transform: transform,
                textureCoordinates: textureCoordinates
            ),
            index: 1
        )
        pass.setVertexBuffer(vertexBuffer, index: 0)
        pass.drawIndexedPrimitives(
            .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer
        )
    }
}

private struct PrimitiveVertex: BitwiseCopyable {
    let position: SIMD2<Float>
    let color: SIMD4<Float>
    let textureCoordinate: SIMD2<Float>

    static func make(
        position: SIMD2<Float>,
        color: PixlGraphics.Color,
        textureCoordinate: SIMD2<Float> = .zero
    ) -> Self {
        .init(
            position: position,
            color: color,
            textureCoordinate: textureCoordinate
        )
    }
}

extension VertexLayout {
    static var primitive: VertexLayout {
        let layout = VertexLayout(bufferCapacity: 1, attributeCapacity: 3)
        layout.append(
            .init(
                bufferIndex: 0,
                stride: UInt64(MemoryLayout<PrimitiveVertex>.stride)
            )
        )
        layout.append(
            .init(location: 0, bufferIndex: 0, format: .float32x2, offset: 0)
        )
        layout.append(
            .init(
                location: 1,
                bufferIndex: 0,
                format: .float32x4,
                offset: UInt64(
                    MemoryLayout<PrimitiveVertex>.offset(of: \.color)!
                )
            )
        )
        layout.append(
            .init(
                location: 2,
                bufferIndex: 0,
                format: .float32x2,
                offset: UInt64(
                    MemoryLayout<PrimitiveVertex>.offset(
                        of: \.textureCoordinate
                    )!
                )
            )
        )
        return layout
    }
}
