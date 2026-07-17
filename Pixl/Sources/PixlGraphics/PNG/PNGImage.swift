import Swift

package struct PNGImage: Sendable {
    package let width: Int
    package let height: Int
    package let rgba8: [UInt8]

    package init(decoding bytes: [UInt8]) throws {
        let decoded = try PNG.decode(bytes)
        width = decoded.width
        height = decoded.height
        rgba8 = decoded.rgba8
    }
}

private enum PNG {
    struct Header {
        let width: Int
        let height: Int
        let bitDepth: Int
        let colorType: Int
        let interlaced: Bool

        var channelCount: Int {
            switch colorType {
            case 0, 3: 1
            case 2: 3
            case 4: 2
            case 6: 4
            default: 0
            }
        }

        var bitsPerPixel: Int { channelCount * bitDepth }
    }

    struct Decoded {
        let width: Int
        let height: Int
        let rgba8: [UInt8]
    }

    struct Transparency {
        var grayscale: Int?
        var red: Int?
        var green: Int?
        var blue: Int?
        var palette: [UInt8] = []
    }

    struct Parsed {
        let header: Header
        let palette: [UInt8]
        let transparency: Transparency
        let compressed: [UInt8]
    }

    static func decode(_ bytes: [UInt8]) throws -> Decoded {
        let parsed = try parse(bytes)
        let header = parsed.header
        if header.colorType == 3 {
            guard !parsed.palette.isEmpty else { throw PNGError.invalidData }
        }
        let passes = scanPasses(for: header)
        let expectedSize = try passes.reduce(0) { total, pass in
            let rowBytes = try byteCount(
                width: pass.width,
                bitsPerPixel: header.bitsPerPixel
            )
            let rowSize = rowBytes.addingReportingOverflow(1)
            guard !rowSize.overflow else { throw PNGError.invalidData }
            let passSize = rowSize.partialValue
                .multipliedReportingOverflow(by: pass.height)
            guard !passSize.overflow,
                  total <= Int.max - passSize.partialValue
            else { throw PNGError.invalidData }
            return total + passSize.partialValue
        }
        let inflated = try Zlib.decompress(
            parsed.compressed,
            maximumOutputSize: expectedSize
        )
        guard inflated.count == expectedSize else {
            throw PNGError.invalidData
        }
        return try pixels(
            inflated,
            header: header,
            palette: parsed.palette,
            transparency: parsed.transparency,
            passes: passes
        )
    }

    private static func parse(_ bytes: [UInt8]) throws -> Parsed {
        try bytes.withParserSpan { input in
            let signature = try [UInt8](parsing: &input, byteCount: 8)
            guard signature == [137, 80, 78, 71, 13, 10, 26, 10] else {
                throw PNGError.invalidData
            }

            var header: Header?
            var palette: [UInt8] = []
            var transparency = Transparency()
            var compressed: [UInt8] = []
            var reachedEnd = false

            while !reachedEnd {
                let length = try Int(
                    exactly: UInt32(parsingBigEndian: &input)
                ).unwrap(or: PNGError.invalidData)
                let typeBytes = try [UInt8](
                    parsing: &input,
                    byteCount: 4
                )
                guard typeBytes.allSatisfy({
                    (65...90).contains($0) || (97...122).contains($0)
                }) else { throw PNGError.invalidData }
                let data = try [UInt8](
                    parsing: &input,
                    byteCount: length
                )
                let expectedCRC = try UInt32(parsingBigEndian: &input)
                guard crc32(typeBytes + data) == expectedCRC else {
                    throw PNGError.invalidData
                }

                let type = String(decoding: typeBytes, as: UTF8.self)
                switch type {
                case "IHDR":
                    guard header == nil else { throw PNGError.invalidData }
                    header = try parseHeader(data)
                case "PLTE":
                    guard !data.isEmpty,
                          data.count % 3 == 0,
                          data.count <= 768
                    else { throw PNGError.invalidData }
                    palette = data
                case "tRNS":
                    guard let header else { throw PNGError.invalidData }
                    transparency = try parseTransparency(
                        data,
                        colorType: header.colorType
                    )
                case "IDAT":
                    guard header != nil else { throw PNGError.invalidData }
                    compressed.append(contentsOf: data)
                case "IEND":
                    guard data.isEmpty else { throw PNGError.invalidData }
                    reachedEnd = true
                default:
                    if type.first?.isLowercase == false {
                        throw PNGError.unsupported
                    }
                }
            }

            guard input.isEmpty, let header, !compressed.isEmpty else {
                throw PNGError.invalidData
            }
            return Parsed(
                header: header,
                palette: palette,
                transparency: transparency,
                compressed: compressed
            )
        }
    }

    private static func parseHeader(_ data: [UInt8]) throws -> Header {
        guard data.count == 13 else { throw PNGError.invalidData }
        let width = try positiveInt(data, offset: 0)
        let height = try positiveInt(data, offset: 4)
        let bitDepth = Int(data[8])
        let colorType = Int(data[9])
        let validDepths: [Int]
        switch colorType {
        case 0: validDepths = [1, 2, 4, 8, 16]
        case 2, 4, 6: validDepths = [8, 16]
        case 3: validDepths = [1, 2, 4, 8]
        default: throw PNGError.unsupported
        }
        guard validDepths.contains(bitDepth),
              data[10] == 0,
              data[11] == 0,
              data[12] <= 1
        else { throw PNGError.unsupported }
        return Header(
            width: width,
            height: height,
            bitDepth: bitDepth,
            colorType: colorType,
            interlaced: data[12] == 1
        )
    }

    private static func parseTransparency(
        _ data: [UInt8],
        colorType: Int
    ) throws -> Transparency {
        var result = Transparency()
        switch colorType {
        case 0:
            guard data.count == 2 else { throw PNGError.invalidData }
            result.grayscale = Int(data[0]) << 8 | Int(data[1])
        case 2:
            guard data.count == 6 else { throw PNGError.invalidData }
            result.red = Int(data[0]) << 8 | Int(data[1])
            result.green = Int(data[2]) << 8 | Int(data[3])
            result.blue = Int(data[4]) << 8 | Int(data[5])
        case 3:
            guard data.count <= 256 else { throw PNGError.invalidData }
            result.palette = data
        default:
            throw PNGError.invalidData
        }
        return result
    }

    private static func pixels(
        _ bytes: [UInt8],
        header: Header,
        palette: [UInt8],
        transparency: Transparency,
        passes: [ScanPass]
    ) throws -> Decoded {
        let pixelCount = header.width.multipliedReportingOverflow(
            by: header.height
        )
        guard !pixelCount.overflow,
              pixelCount.partialValue <= Int.max / 4
        else { throw PNGError.invalidData }
        var output = [UInt8](
            repeating: 0,
            count: pixelCount.partialValue * 4
        )
        var sourceOffset = 0
        let filterBytesPerPixel = max(1, (header.bitsPerPixel + 7) / 8)

        for pass in passes where pass.width > 0 && pass.height > 0 {
            let rowByteCount = try byteCount(
                width: pass.width,
                bitsPerPixel: header.bitsPerPixel
            )
            var previous = [UInt8](repeating: 0, count: rowByteCount)
            for passY in 0..<pass.height {
                guard sourceOffset < bytes.count else {
                    throw PNGError.invalidData
                }
                let filter = bytes[sourceOffset]
                sourceOffset += 1
                guard sourceOffset <= bytes.count - rowByteCount else {
                    throw PNGError.invalidData
                }
                var row = Array(
                    bytes[sourceOffset..<(sourceOffset + rowByteCount)]
                )
                sourceOffset += rowByteCount
                try unfilter(
                    &row,
                    previous: previous,
                    filter: filter,
                    bytesPerPixel: filterBytesPerPixel
                )

                for passX in 0..<pass.width {
                    let rgba = try color(
                        row: row,
                        pixel: passX,
                        header: header,
                        palette: palette,
                        transparency: transparency
                    )
                    let x = pass.startX + passX * pass.stepX
                    let y = pass.startY + passY * pass.stepY
                    let offset = (y * header.width + x) * 4
                    output[offset] = rgba.0
                    output[offset + 1] = rgba.1
                    output[offset + 2] = rgba.2
                    output[offset + 3] = rgba.3
                }
                previous = row
            }
        }
        guard sourceOffset == bytes.count else { throw PNGError.invalidData }
        return Decoded(
            width: header.width,
            height: header.height,
            rgba8: output
        )
    }

    private static func color(
        row: [UInt8],
        pixel: Int,
        header: Header,
        palette: [UInt8],
        transparency: Transparency
    ) throws -> (UInt8, UInt8, UInt8, UInt8) {
        let base = pixel * header.channelCount
        switch header.colorType {
        case 0:
            let gray = try sample(row, index: base, depth: header.bitDepth)
            let value = scale(gray, depth: header.bitDepth)
            let alpha: UInt8 = gray == transparency.grayscale ? 0 : 255
            return (value, value, value, alpha)
        case 2:
            let red = try sample(row, index: base, depth: header.bitDepth)
            let green = try sample(row, index: base + 1, depth: header.bitDepth)
            let blue = try sample(row, index: base + 2, depth: header.bitDepth)
            let transparent = red == transparency.red
                && green == transparency.green
                && blue == transparency.blue
            return (
                scale(red, depth: header.bitDepth),
                scale(green, depth: header.bitDepth),
                scale(blue, depth: header.bitDepth),
                transparent ? 0 : 255
            )
        case 3:
            let index = try sample(row, index: pixel, depth: header.bitDepth)
            guard index < palette.count / 3 else { throw PNGError.invalidData }
            return (
                palette[index * 3],
                palette[index * 3 + 1],
                palette[index * 3 + 2],
                index < transparency.palette.count
                    ? transparency.palette[index]
                    : 255
            )
        case 4:
            let gray = try sample(row, index: base, depth: header.bitDepth)
            let alpha = try sample(row, index: base + 1, depth: header.bitDepth)
            let value = scale(gray, depth: header.bitDepth)
            return (value, value, value, scale(alpha, depth: header.bitDepth))
        case 6:
            return (
                scale(try sample(row, index: base, depth: header.bitDepth), depth: header.bitDepth),
                scale(try sample(row, index: base + 1, depth: header.bitDepth), depth: header.bitDepth),
                scale(try sample(row, index: base + 2, depth: header.bitDepth), depth: header.bitDepth),
                scale(try sample(row, index: base + 3, depth: header.bitDepth), depth: header.bitDepth)
            )
        default:
            throw PNGError.unsupported
        }
    }

    private static func sample(
        _ row: [UInt8],
        index: Int,
        depth: Int
    ) throws -> Int {
        let bitOffset = index * depth
        guard bitOffset / 8 < row.count else { throw PNGError.invalidData }
        switch depth {
        case 1, 2, 4:
            let shift = 8 - depth - bitOffset % 8
            return Int(row[bitOffset / 8] >> shift) & ((1 << depth) - 1)
        case 8:
            return Int(row[bitOffset / 8])
        case 16:
            guard bitOffset / 8 + 1 < row.count else {
                throw PNGError.invalidData
            }
            return Int(row[bitOffset / 8]) << 8 | Int(row[bitOffset / 8 + 1])
        default:
            throw PNGError.unsupported
        }
    }

    private static func scale(_ sample: Int, depth: Int) -> UInt8 {
        if depth == 16 { return UInt8(sample >> 8) }
        if depth == 8 { return UInt8(sample) }
        return UInt8(sample * 255 / ((1 << depth) - 1))
    }

    private static func unfilter(
        _ row: inout [UInt8],
        previous: [UInt8],
        filter: UInt8,
        bytesPerPixel: Int
    ) throws {
        for index in row.indices {
            let left = index >= bytesPerPixel ? row[index - bytesPerPixel] : 0
            let above = previous[index]
            let upperLeft = index >= bytesPerPixel
                ? previous[index - bytesPerPixel]
                : 0
            switch filter {
            case 0:
                break
            case 1:
                row[index] &+= left
            case 2:
                row[index] &+= above
            case 3:
                row[index] &+= UInt8((Int(left) + Int(above)) / 2)
            case 4:
                row[index] &+= paeth(left, above, upperLeft)
            default:
                throw PNGError.invalidData
            }
        }
    }

    private static func paeth(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> UInt8 {
        let a = Int(a)
        let b = Int(b)
        let c = Int(c)
        let estimate = a + b - c
        let pa = abs(estimate - a)
        let pb = abs(estimate - b)
        let pc = abs(estimate - c)
        if pa <= pb && pa <= pc { return UInt8(a) }
        if pb <= pc { return UInt8(b) }
        return UInt8(c)
    }

    private static func byteCount(
        width: Int,
        bitsPerPixel: Int
    ) throws -> Int {
        let bits = width.multipliedReportingOverflow(by: bitsPerPixel)
        guard !bits.overflow, bits.partialValue <= Int.max - 7 else {
            throw PNGError.invalidData
        }
        return (bits.partialValue + 7) / 8
    }

    private static func positiveInt(
        _ bytes: [UInt8],
        offset: Int
    ) throws -> Int {
        let value = bytes[offset..<(offset + 4)].reduce(UInt32.zero) {
            ($0 << 8) | UInt32($1)
        }
        guard value > 0, let result = Int(exactly: value) else {
            throw PNGError.invalidData
        }
        return result
    }

    private static func scanPasses(for header: Header) -> [ScanPass] {
        guard header.interlaced else {
            return [ScanPass(width: header.width, height: header.height)]
        }
        return [
            ScanPass(header, startX: 0, startY: 0, stepX: 8, stepY: 8),
            ScanPass(header, startX: 4, startY: 0, stepX: 8, stepY: 8),
            ScanPass(header, startX: 0, startY: 4, stepX: 4, stepY: 8),
            ScanPass(header, startX: 2, startY: 0, stepX: 4, stepY: 4),
            ScanPass(header, startX: 0, startY: 2, stepX: 2, stepY: 4),
            ScanPass(header, startX: 1, startY: 0, stepX: 2, stepY: 2),
            ScanPass(header, startX: 0, startY: 1, stepX: 1, stepY: 2),
        ]
    }
}

private struct ScanPass {
    let startX: Int
    let startY: Int
    let stepX: Int
    let stepY: Int
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        startX = 0
        startY = 0
        stepX = 1
        stepY = 1
        self.width = width
        self.height = height
    }

    init(
        _ header: PNG.Header,
        startX: Int,
        startY: Int,
        stepX: Int,
        stepY: Int
    ) {
        self.startX = startX
        self.startY = startY
        self.stepX = stepX
        self.stepY = stepY
        width = header.width > startX
            ? (header.width - startX + stepX - 1) / stepX
            : 0
        height = header.height > startY
            ? (header.height - startY + stepY - 1) / stepY
            : 0
    }
}

private enum PNGError: Error {
    case invalidData
    case unsupported
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> any Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}

private func crc32(_ bytes: [UInt8]) -> UInt32 {
    var crc = UInt32.max
    for byte in bytes {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = crc & 1 == 1
                ? 0xedb8_8320 ^ (crc >> 1)
                : crc >> 1
        }
    }
    return crc ^ UInt32.max
}
