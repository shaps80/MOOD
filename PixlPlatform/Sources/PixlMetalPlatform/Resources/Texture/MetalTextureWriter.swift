@preconcurrency import Metal
import PixlPlatform
import Swift

final class MetalTextureWriter: TextureWriter, @unchecked Sendable {
    private let texture: any MTLTexture
    private let queue: any MTLCommandQueue
    private let descriptor: TextureDescriptor

    init(
        texture: any MTLTexture,
        queue: any MTLCommandQueue,
        descriptor: TextureDescriptor
    ) {
        self.texture = texture
        self.queue = queue
        self.descriptor = descriptor
    }

    func write(
        copying bytes: [UInt8],
        bytesPerRow: UInt32
    ) async throws(DeviceError) {
        guard descriptor.sampleCount == 1,
              descriptor.size.depthOrArrayLayers == 1,
              descriptor.format == .rgba8Unorm
                || descriptor.format == .bgra8Unorm,
              let width = UInt32(exactly: descriptor.size.width),
              let height = UInt32(exactly: descriptor.size.height),
              width > 0,
              height > 0,
              !width.multipliedReportingOverflow(by: 4).overflow
        else {
            throw .invalidTextureDescriptor(descriptor)
        }

        let minimumBytesPerRow = width * 4
        let requiredByteCount = UInt64(bytesPerRow)
            .multipliedReportingOverflow(by: UInt64(height))
        guard bytesPerRow >= minimumBytesPerRow,
              !requiredByteCount.overflow,
              UInt64(bytes.count) >= requiredByteCount.partialValue
        else {
            throw .invalidTextureDescriptor(descriptor)
        }

        let alignedBytesPerRow = (Int(bytesPerRow) + 255) & ~255
        let stagingSize = alignedBytesPerRow
            .multipliedReportingOverflow(by: Int(height))
        guard !stagingSize.overflow,
              let staging = texture.device.makeBuffer(
                length: stagingSize.partialValue,
                options: .storageModeShared
              )
        else {
            throw .resourceCreationFailed(.buffer)
        }

        bytes.withUnsafeBytes { source in
            let destination = staging.contents()
            var row = 0
            while row < Int(height) {
                destination
                    .advanced(by: row * alignedBytesPerRow)
                    .copyMemory(
                        from: source.baseAddress!.advanced(
                            by: row * Int(bytesPerRow)
                        ),
                        byteCount: Int(bytesPerRow)
                    )
                row += 1
            }
        }

        guard let commandBuffer = queue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder()
        else {
            throw .resourceCreationFailed(.texture)
        }

        blit.copy(
            from: staging,
            sourceOffset: 0,
            sourceBytesPerRow: alignedBytesPerRow,
            sourceBytesPerImage: stagingSize.partialValue,
            sourceSize: MTLSize(
                width: Int(width),
                height: Int(height),
                depth: 1
            ),
            to: texture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()

        let succeeded = await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { commandBuffer in
                continuation.resume(
                    returning: commandBuffer.status == .completed
                )
            }
            commandBuffer.commit()
        }

        guard succeeded else {
            throw .resourceCreationFailed(.texture)
        }
    }
}
