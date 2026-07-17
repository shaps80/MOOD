import PixlPlatform
import Swift

enum WAVDecoder {
    private struct Format {
        let encoding: UInt16
        let channelCount: UInt16
        let sampleRate: UInt32
        let blockAlignment: UInt16
        let bitsPerSample: UInt16
    }

    static func decode(
        _ bytes: [UInt8],
        path: AssetPath
    ) throws(AssetError) -> DecodedSound {
        guard bytes.count >= 12,
              matches(bytes, at: 0, [82, 73, 70, 70]),
              matches(bytes, at: 8, [87, 65, 86, 69]),
              let riffSize = uint32(bytes, at: 4),
              let declaredEnd = Int(exactly: UInt64(riffSize) + 8),
              declaredEnd <= bytes.count
        else {
            throw .invalidSound(path.value)
        }

        var format: Format?
        var sampleRange: Range<Int>?
        var offset = 12

        while offset <= declaredEnd - 8 {
            guard let chunkSize = uint32(bytes, at: offset + 4),
                  let size = Int(exactly: chunkSize)
            else {
                throw .invalidSound(path.value)
            }
            let dataStart = offset + 8
            let endResult = dataStart.addingReportingOverflow(size)
            guard !endResult.overflow,
                  endResult.partialValue <= declaredEnd
            else {
                throw .invalidSound(path.value)
            }
            let dataEnd = endResult.partialValue

            if matches(bytes, at: offset, [102, 109, 116, 32]) {
                guard size >= 16,
                      let encoding = uint16(bytes, at: dataStart),
                      let channelCount = uint16(bytes, at: dataStart + 2),
                      let sampleRate = uint32(bytes, at: dataStart + 4),
                      let blockAlignment = uint16(bytes, at: dataStart + 12),
                      let bitsPerSample = uint16(bytes, at: dataStart + 14)
                else {
                    throw .invalidSound(path.value)
                }
                format = Format(
                    encoding: encoding,
                    channelCount: channelCount,
                    sampleRate: sampleRate,
                    blockAlignment: blockAlignment,
                    bitsPerSample: bitsPerSample
                )
            } else if matches(bytes, at: offset, [100, 97, 116, 97]),
                      sampleRange == nil {
                sampleRange = dataStart..<dataEnd
            }

            let paddedSize = size + (size & 1)
            let nextResult = dataStart.addingReportingOverflow(paddedSize)
            guard !nextResult.overflow else {
                throw .invalidSound(path.value)
            }
            offset = nextResult.partialValue
        }

        guard let format,
              let sampleRange,
              format.sampleRate > 0,
              format.channelCount == 1 || format.channelCount == 2
        else {
            throw .unsupportedSound(path.value)
        }

        let bytesPerSample: Int
        switch (format.encoding, format.bitsPerSample) {
        case (1, 8): bytesPerSample = 1
        case (1, 16): bytesPerSample = 2
        case (1, 24): bytesPerSample = 3
        case (1, 32), (3, 32): bytesPerSample = 4
        default: throw .unsupportedSound(path.value)
        }

        let expectedAlignment = Int(format.channelCount)
            * bytesPerSample
        guard Int(format.blockAlignment) == expectedAlignment,
              !sampleRange.isEmpty,
              sampleRange.count.isMultiple(of: expectedAlignment)
        else {
            throw .invalidSound(path.value)
        }

        let frameCount = sampleRange.count / expectedAlignment
        guard let portableFrameCount = UInt32(exactly: frameCount) else {
            throw .invalidSound(path.value)
        }
        let layout: ChannelLayout = format.channelCount == 1
            ? .mono
            : .stereo
        let descriptor = SoundDescriptor(
            sampleRate: format.sampleRate,
            channelLayout: layout,
            frameCount: portableFrameCount
        )
        var samples = [Float](
            repeating: 0,
            count: frameCount * Int(format.channelCount)
        )

        var frame = 0
        while frame < frameCount {
            var channel = 0
            while channel < Int(format.channelCount) {
                let sampleOffset = sampleRange.lowerBound
                    + frame * expectedAlignment
                    + channel * bytesPerSample
                let sample = try decodeSample(
                    bytes,
                    at: sampleOffset,
                    encoding: format.encoding,
                    bitsPerSample: format.bitsPerSample,
                    path: path
                )
                samples[channel * frameCount + frame] = sample
                channel += 1
            }
            frame += 1
        }

        return DecodedSound(samples: samples, descriptor: descriptor)
    }

    private static func decodeSample(
        _ bytes: [UInt8],
        at offset: Int,
        encoding: UInt16,
        bitsPerSample: UInt16,
        path: AssetPath
    ) throws(AssetError) -> Float {
        switch (encoding, bitsPerSample) {
        case (1, 8):
            return Float(Int(bytes[offset]) - 128) / 128

        case (1, 16):
            let value = Int16(bitPattern: uint16(bytes, at: offset)!)
            return Float(value) / 32_768

        case (1, 24):
            var value = Int32(bytes[offset])
                | Int32(bytes[offset + 1]) << 8
                | Int32(bytes[offset + 2]) << 16
            if value & 0x0080_0000 != 0 {
                value |= ~0x00ff_ffff
            }
            return Float(value) / 8_388_608

        case (1, 32):
            let value = Int32(bitPattern: uint32(bytes, at: offset)!)
            return Float(Double(value) / 2_147_483_648)

        case (3, 32):
            let value = Float(
                bitPattern: uint32(bytes, at: offset)!
            )
            guard value.isFinite else {
                throw .invalidSound(path.value)
            }
            return value

        default:
            throw .unsupportedSound(path.value)
        }
    }

    private static func matches(
        _ bytes: [UInt8],
        at offset: Int,
        _ value: [UInt8]
    ) -> Bool {
        guard offset >= 0, offset <= bytes.count - value.count else {
            return false
        }
        var index = 0
        while index < value.count {
            guard bytes[offset + index] == value[index] else { return false }
            index += 1
        }
        return true
    }

    private static func uint16(
        _ bytes: [UInt8],
        at offset: Int
    ) -> UInt16? {
        guard offset >= 0, offset <= bytes.count - 2 else { return nil }
        return UInt16(bytes[offset])
            | UInt16(bytes[offset + 1]) << 8
    }

    private static func uint32(
        _ bytes: [UInt8],
        at offset: Int
    ) -> UInt32? {
        guard offset >= 0, offset <= bytes.count - 4 else { return nil }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
