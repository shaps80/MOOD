import Swift

public protocol TextureWriter: Sendable {
    func write(
        copying bytes: [UInt8],
        bytesPerRow: UInt32
    ) async throws(DeviceError)
}
