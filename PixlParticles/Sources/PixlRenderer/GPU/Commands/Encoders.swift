import Swift

public protocol ComputeEncoder: AnyObject {
    var label: String? { get set }
    func setPipeline(_ pipeline: any ComputePipeline)
    func setBuffer(_ buffer: any Buffer, index: Int)
    func setBytes(_ bytes: UnsafeRawBufferPointer, index: Int)
    func dispatchThreadgroups(_ groups: ThreadGrid, threads: ThreadGrid)
    func dispatchThreads(_ grid: ThreadGrid, threads: ThreadGrid)
    func dispatchThreadgroups(
        indirectBuffer: any Buffer,
        threads: ThreadGrid
    )
    func endEncoding()
}

public protocol RenderEncoder: AnyObject {
    var label: String? { get set }
    func setPipeline(_ pipeline: any RenderPipeline)
    func setDepthState(_ state: any DepthState)
    func setFragmentBytes(_ bytes: UnsafeRawBufferPointer, index: Int)
    func setFragmentBuffer(_ buffer: any Buffer, index: Int)
    func setVertexBuffer(_ buffer: any Buffer, index: Int)
    func setVertexBytes(_ bytes: UnsafeRawBufferPointer, index: Int)
    func drawPrimitives(
        _ primitive: Primitive,
        indirectBuffer: any Buffer
    )
    func drawPrimitives(
        _ primitive: Primitive,
        vertexStart: Int,
        vertexCount: Int
    )
    func drawPrimitives(
        _ primitive: Primitive,
        vertexStart: Int,
        vertexCount: Int,
        instanceCount: Int
    )
    /// Repeated draw with inherited bindings; adapters may cache encoded commands.
    func drawReusablePrimitives(_ primitive: Primitive, vertexCount: Int, instanceCount: Int)
    func endEncoding()
}

public extension ComputeEncoder {
    func setValue<Value: BitwiseCopyable>(_ value: Value, index: Int) {
        var value = value
        withUnsafeBytes(of: &value) { setBytes($0, index: index) }
    }
}

public extension RenderEncoder {
    func setFragmentValue<Value: BitwiseCopyable>(_ value: Value, index: Int) {
        var value = value
        withUnsafeBytes(of: &value) { setFragmentBytes($0, index: index) }
    }

    func drawReusablePrimitives(_ primitive: Primitive, vertexCount: Int, instanceCount: Int) {
        drawPrimitives(primitive, vertexStart: 0, vertexCount: vertexCount, instanceCount: instanceCount)
    }

    func setVertexValue<Value: BitwiseCopyable>(
        _ value: Value,
        index: Int
    ) {
        var value = value
        withUnsafeBytes(of: &value) { setVertexBytes($0, index: index) }
    }

}
