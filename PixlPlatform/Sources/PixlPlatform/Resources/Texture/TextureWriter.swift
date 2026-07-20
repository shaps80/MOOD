import Swift

/// Asynchronous same-size content replacement for one existing texture.
public protocol TextureWriter: Sendable {
    /// Replaces the texture's complete pixel contents without changing its handle.
    /// - Parameters:
    ///   - bytes: Source pixel bytes in the texture's existing format.
    ///   - bytesPerRow: Source stride between consecutive pixel rows.
    /// - Throws: ``DeviceError`` when the texture is unavailable or the upload is invalid.
    func write(
        copying bytes: [UInt8],
        bytesPerRow: UInt32
    ) async throws(DeviceError)
}
