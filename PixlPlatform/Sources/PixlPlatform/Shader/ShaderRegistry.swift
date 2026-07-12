import Swift

public final class ShaderRegistry {
    private let device: any Device
    private var libraries: UnsafeMutablePointer<any ShaderLibrary>?
    private var capacity: Int = 0

    public private(set) var count: Int = 0

    package init(device: any Device) {
        self.device = device
    }

    deinit {
        guard let libraries else { return }
        libraries.deinitialize(count: count)
        libraries.deallocate()
    }

    public func append(_ shader: borrowing Shader) throws {
        let library = try device.makeShaderLibrary(shader)
        ensureCapacity(for: count + 1)
        libraries!.advanced(by: count).initialize(to: library)
        count += 1
    }

    private func ensureCapacity(for requiredCapacity: Int) {
        guard requiredCapacity > capacity else { return }

        let newCapacity = max(4, capacity * 2)
        let newLibraries = UnsafeMutablePointer<any ShaderLibrary>.allocate(
            capacity: newCapacity
        )

        if let libraries {
            for index in 0..<count {
                newLibraries.advanced(by: index).initialize(
                    to: libraries.advanced(by: index).pointee
                )
            }
            libraries.deinitialize(count: count)
            libraries.deallocate()
        }

        libraries = newLibraries
        capacity = newCapacity
    }
}
