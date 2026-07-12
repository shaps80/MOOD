import Swift

/// Fixed-capacity GPU vertex-input layout.
///
/// Layouts are assembled during pipeline setup and contain no `Array` storage.
/// They are mutable only while being assembled; pipeline creation consumes their
/// current description into a backend-native pipeline descriptor.
public final class VertexLayout {
    private let buffers: UnsafeMutablePointer<VertexBufferLayout>
    private let attributes: UnsafeMutablePointer<VertexAttribute>

    public let bufferCapacity: UInt32
    public let attributeCapacity: UInt32
    public private(set) var bufferCount: UInt32 = 0
    public private(set) var attributeCount: UInt32 = 0

    package subscript(buffer index: UInt32) -> VertexBufferLayout {
        buffers[Int(index)]
    }

    package subscript(attribute index: UInt32) -> VertexAttribute {
        attributes[Int(index)]
    }

    public init(bufferCapacity: UInt32, attributeCapacity: UInt32) {
        self.bufferCapacity = bufferCapacity
        self.attributeCapacity = attributeCapacity
        buffers = .allocate(capacity: max(1, Int(bufferCapacity)))
        attributes = .allocate(capacity: max(1, Int(attributeCapacity)))
    }

    deinit {
        buffers.deinitialize(count: Int(bufferCount))
        buffers.deallocate()
        attributes.deinitialize(count: Int(attributeCount))
        attributes.deallocate()
    }

    public func append(_ layout: consuming VertexBufferLayout) {
        precondition(bufferCount < bufferCapacity, "Vertex buffer layout capacity exceeded")
        precondition(
            !containsBuffer(at: layout.bufferIndex),
            "Vertex buffer layout already exists for this buffer index"
        )

        buffers.advanced(by: Int(bufferCount)).initialize(to: layout)
        bufferCount += 1
    }

    public func append(_ attribute: consuming VertexAttribute) {
        precondition(attributeCount < attributeCapacity, "Vertex attribute capacity exceeded")
        precondition(
            containsBuffer(at: attribute.bufferIndex),
            "Vertex attribute references an undeclared buffer index"
        )
        precondition(
            !containsAttribute(at: attribute.location),
            "Vertex attribute already exists for this shader location"
        )

        attributes.advanced(by: Int(attributeCount)).initialize(to: attribute)
        attributeCount += 1
    }

    private func containsBuffer(at bufferIndex: UInt32) -> Bool {
        for index in 0..<bufferCount where buffers[Int(index)].bufferIndex == bufferIndex {
            return true
        }
        return false
    }

    private func containsAttribute(at location: UInt32) -> Bool {
        for index in 0..<attributeCount where attributes[Int(index)].location == location {
            return true
        }
        return false
    }
}
