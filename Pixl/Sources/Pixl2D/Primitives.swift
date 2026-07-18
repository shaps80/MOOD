import PixlPlatform
import Swift

package struct TextureCoordinates: BitwiseCopyable, Sendable {
    package var origin: SIMD2<Float>
    package var scale: SIMD2<Float>

    package init(
        origin: SIMD2<Float> = .zero,
        scale: SIMD2<Float> = .init(repeating: 1)
    ) {
        self.origin = origin
        self.scale = scale
    }
}

private struct PrimitiveParameters: BitwiseCopyable {
    let transform: Transform2D
    let textureCoordinates: TextureCoordinates
}

/// Immutable coloured triangle geometry centred at the world origin.
public struct Triangle: Sendable {
    private let vertexBuffer: Buffer

    /// Creates a GPU-only coloured triangle.
    ///
    /// - Parameters:
    ///   - device: Device that owns the immutable vertex buffer.
    ///   - colors: Colours for the top, lower-left, and lower-right vertices.
    public init(
        device: any Device,
        colors: (Color, Color, Color) = (
            .init(red: 1, green: 1, blue: 0),
            .init(red: 0, green: 1, blue: 1),
            .init(red: 1, green: 0, blue: 1)
        )
    ) throws {
        var vertices = (
            PrimitiveVertex.make(position: .init(0, 0.5), color: colors.0),
            PrimitiveVertex.make(position: .init(-0.5, -0.5), color: colors.1),
            PrimitiveVertex.make(position: .init(0.5, -0.5), color: colors.2)
        )
        vertexBuffer = try withUnsafeBytes(of: &vertices) {
            try device.makeBuffer(copying: $0, usage: .vertex, memory: .gpuOnly)
        }
    }

    /// Creates a GPU-only triangle with one colour at every vertex.
    ///
    /// - Parameters:
    ///   - device: Device that owns the immutable vertex buffer.
    ///   - color: Colour assigned to all three vertices.
    public init(device: any Device, color: Color) throws {
        try self.init(device: device, colors: (color, color, color))
    }

    /// Records this triangle's transform, vertex binding, and primitive draw.
    ///
    /// - Parameters:
    ///   - pass: Render-pass encoder that already has a compatible pipeline.
    ///   - transform: Transform uploaded to the built-in coloured vertex shader.
    public func draw(on pass: RenderPassEncoder, transform: Transform2D) {
        pass.setVertexBytes(
            of: PrimitiveParameters(
                transform: transform,
                textureCoordinates: .init()
            ),
            index: 1
        )
        pass.setVertexBuffer(vertexBuffer, index: 0)
        pass.drawPrimitives(.triangle, vertexCount: 3)
    }
}

/// Immutable indexed coloured quad geometry centred at the world origin.
public struct Quad: Sendable {
    private let vertexBuffer: Buffer
    private let indexBuffer: Buffer

    /// Creates a GPU-only indexed coloured quad.
    ///
    /// - Parameters:
    ///   - device: Device that owns the immutable vertex and index buffers.
    ///   - colors: Colours for the top-left, bottom-left, bottom-right, and
    ///     top-right vertices.
    public init(
        device: any Device,
        colors: (Color, Color, Color, Color) = (
            .init(red: 1, green: 1, blue: 0),
            .init(red: 0, green: 1, blue: 1),
            .init(red: 1, green: 0, blue: 1),
            .white
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
        var indices: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) = (0, 1, 2, 0, 2, 3)

        vertexBuffer = try withUnsafeBytes(of: &vertices) {
            try device.makeBuffer(copying: $0, usage: .vertex, memory: .gpuOnly)
        }
        indexBuffer = try withUnsafeBytes(of: &indices) {
            try device.makeBuffer(copying: $0, usage: .index, memory: .gpuOnly)
        }
    }

    /// Creates a GPU-only quad with one colour at every vertex.
    ///
    /// - Parameters:
    ///   - device: Device that owns the immutable vertex and index buffers.
    ///   - color: Colour assigned to all four vertices.
    public init(device: any Device, color: Color) throws {
        try self.init(device: device, colors: (color, color, color, color))
    }

    /// Records this quad's transform, vertex binding, and indexed primitive draw.
    ///
    /// - Parameters:
    ///   - pass: Render-pass encoder that already has a compatible pipeline.
    ///   - transform: Transform uploaded to the built-in coloured vertex shader.
    public func draw(on pass: RenderPassEncoder, transform: Transform2D) {
        draw(
            on: pass,
            transform: transform,
            textureCoordinates: .init()
        )
    }

    package func draw(
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
        color: Color,
        textureCoordinate: SIMD2<Float> = .zero
    ) -> Self {
        .init(
            position: position,
            color: color,
            textureCoordinate: textureCoordinate
        )
    }
}

public extension VertexLayout {
    static var primitive: VertexLayout {
        let layout = VertexLayout(bufferCapacity: 1, attributeCapacity: 3)
        layout.append(
            .init(bufferIndex: 0, stride: UInt64(MemoryLayout<PrimitiveVertex>.stride))
        )
        layout.append(
            .init(location: 0, bufferIndex: 0, format: .float32x2, offset: 0)
        )
        layout.append(
            .init(
                location: 1,
                bufferIndex: 0,
                format: .float32x4,
                offset: UInt64(MemoryLayout<PrimitiveVertex>.offset(of: \.color)!)
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
