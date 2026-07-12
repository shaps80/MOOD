import Swift

public final class ShaderRegistry {
    private struct Entry {
        let shader: Shader
        let library: any ShaderLibrary
    }

    private let device: any Device
    private var entries: UnsafeMutablePointer<Entry>?
    private var capacity: Int = 0

    public private(set) var count: Int = 0

    package init(device: any Device) {
        self.device = device
    }

    deinit {
        guard let entries else { return }
        entries.deinitialize(count: count)
        entries.deallocate()
    }

    public func append(_ shader: Shader) throws {
        if library(for: shader) != nil { return }

        let library = try device.makeShaderLibrary(shader)
        ensureCapacity(for: count + 1)
        entries!.advanced(by: count).initialize(to: .init(shader: shader, library: library))
        count += 1
    }

    package func library(for shader: Shader) -> (any ShaderLibrary)? {
        guard let entries else { return nil }

        for index in 0..<count where entries[Int(index)].shader === shader {
            return entries[Int(index)].library
        }
        return nil
    }

    private func ensureCapacity(for requiredCapacity: Int) {
        guard requiredCapacity > capacity else { return }

        let newCapacity = max(4, capacity * 2)
        let newEntries = UnsafeMutablePointer<Entry>.allocate(
            capacity: newCapacity
        )

        if let entries {
            for index in 0..<count {
                newEntries.advanced(by: index).initialize(
                    to: entries.advanced(by: index).pointee
                )
            }
            entries.deinitialize(count: count)
            entries.deallocate()
        }

        entries = newEntries
        capacity = newCapacity
    }
}
