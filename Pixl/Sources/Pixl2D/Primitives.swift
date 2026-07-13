import PixlPlatform
import Swift

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
            ColorGeometry.vertex(position: .init(0, 0.5), color: colors.0),
            ColorGeometry.vertex(position: .init(-0.5, -0.5), color: colors.1),
            ColorGeometry.vertex(position: .init(0.5, -0.5), color: colors.2)
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
        pass.setVertexBytes(of: transform, index: 1)
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
            ColorGeometry.vertex(position: .init(-0.5, 0.5), color: colors.0),
            ColorGeometry.vertex(position: .init(-0.5, -0.5), color: colors.1),
            ColorGeometry.vertex(position: .init(0.5, -0.5), color: colors.2),
            ColorGeometry.vertex(position: .init(0.5, 0.5), color: colors.3)
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
        pass.setVertexBytes(of: transform, index: 1)
        pass.setVertexBuffer(vertexBuffer, index: 0)
        pass.drawIndexedPrimitives(
            .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: indexBuffer
        )
    }
}

private struct ColorVertex: BitwiseCopyable {
    let position: SIMD2<Float>
    let color: SIMD4<Float>
}

public enum ColorGeometry {
    public static var vertexLayout: VertexLayout {
        let layout = VertexLayout(bufferCapacity: 1, attributeCapacity: 2)
        layout.append(
            .init(bufferIndex: 0, stride: UInt64(MemoryLayout<ColorVertex>.stride))
        )
        layout.append(
            .init(location: 0, bufferIndex: 0, format: .float32x2, offset: 0)
        )
        layout.append(
            .init(
                location: 1,
                bufferIndex: 0,
                format: .float32x4,
                offset: UInt64(MemoryLayout<ColorVertex>.offset(of: \.color)!)
            )
        )
        return layout
    }

    fileprivate static func vertex(position: SIMD2<Float>, color: Color) -> ColorVertex {
        .init(
            position: position,
            color: .init(color.red, color.green, color.blue, color.alpha)
        )
    }
}
