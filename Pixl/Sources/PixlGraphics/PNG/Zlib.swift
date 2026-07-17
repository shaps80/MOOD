import Swift

enum ZlibError: Error {
    case invalidData
    case outputTooLarge
}

enum Zlib {
    static func decompress(
        _ bytes: [UInt8],
        maximumOutputSize: Int
    ) throws -> [UInt8] {
        guard bytes.count >= 6 else { throw ZlibError.invalidData }
        let cmf = Int(bytes[0])
        let flg = Int(bytes[1])
        guard cmf & 0x0f == 8,
              cmf >> 4 <= 7,
              (cmf << 8 | flg) % 31 == 0,
              flg & 0x20 == 0
        else {
            throw ZlibError.invalidData
        }

        var reader = BitReader(bytes: bytes, byteIndex: 2)
        var output: [UInt8] = []
        output.reserveCapacity(maximumOutputSize)

        var isFinal = false
        while !isFinal {
            isFinal = try reader.readBits(1) == 1
            switch try reader.readBits(2) {
            case 0:
                try reader.alignToByte()
                let length = try reader.readUInt16()
                let complement = try reader.readUInt16()
                guard length ^ complement == 0xffff else {
                    throw ZlibError.invalidData
                }
                try append(
                    reader.readBytes(Int(length)),
                    to: &output,
                    maximumOutputSize: maximumOutputSize
                )
            case 1:
                try inflate(
                    reader: &reader,
                    literalTree: .fixedLiteral,
                    distanceTree: .fixedDistance,
                    output: &output,
                    maximumOutputSize: maximumOutputSize
                )
            case 2:
                let trees = try dynamicTrees(reader: &reader)
                try inflate(
                    reader: &reader,
                    literalTree: trees.literal,
                    distanceTree: trees.distance,
                    output: &output,
                    maximumOutputSize: maximumOutputSize
                )
            default:
                throw ZlibError.invalidData
            }
        }

        guard reader.byteIndex <= bytes.count - 4 else {
            throw ZlibError.invalidData
        }
        let expected = bytes.suffix(4).reduce(UInt32.zero) {
            ($0 << 8) | UInt32($1)
        }
        guard adler32(output) == expected else {
            throw ZlibError.invalidData
        }
        return output
    }

    private static func dynamicTrees(
        reader: inout BitReader
    ) throws -> (literal: HuffmanTree, distance: HuffmanTree) {
        let literalCount = try reader.readBits(5) + 257
        let distanceCount = try reader.readBits(5) + 1
        let codeLengthCount = try reader.readBits(4) + 4
        let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
        var codeLengths = [Int](repeating: 0, count: 19)
        for index in 0..<codeLengthCount {
            codeLengths[order[index]] = try reader.readBits(3)
        }
        let codeLengthTree = try HuffmanTree(lengths: codeLengths)

        let total = literalCount + distanceCount
        var lengths: [Int] = []
        lengths.reserveCapacity(total)
        while lengths.count < total {
            switch try codeLengthTree.decode(reader: &reader) {
            case let length where (0...15).contains(length):
                lengths.append(length)
            case 16:
                guard let previous = lengths.last else {
                    throw ZlibError.invalidData
                }
                let count = try reader.readBits(2) + 3
                guard lengths.count + count <= total else {
                    throw ZlibError.invalidData
                }
                lengths.append(contentsOf: repeatElement(previous, count: count))
            case 17:
                let count = try reader.readBits(3) + 3
                guard lengths.count + count <= total else {
                    throw ZlibError.invalidData
                }
                lengths.append(contentsOf: repeatElement(0, count: count))
            case 18:
                let count = try reader.readBits(7) + 11
                guard lengths.count + count <= total else {
                    throw ZlibError.invalidData
                }
                lengths.append(contentsOf: repeatElement(0, count: count))
            default:
                throw ZlibError.invalidData
            }
        }

        let literal = try HuffmanTree(
            lengths: Array(lengths[..<literalCount])
        )
        guard lengths[256] != 0 else { throw ZlibError.invalidData }
        let distance = try HuffmanTree(
            lengths: Array(lengths[literalCount...])
        )
        return (literal, distance)
    }

    private static func inflate(
        reader: inout BitReader,
        literalTree: HuffmanTree,
        distanceTree: HuffmanTree,
        output: inout [UInt8],
        maximumOutputSize: Int
    ) throws {
        let lengthBases = [
            3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
            35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
        ]
        let lengthExtra = [
            0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
            3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
        ]
        let distanceBases = [
            1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
            257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
            8193, 12289, 16385, 24577,
        ]
        let distanceExtra = [
            0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
            7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
        ]

        while true {
            let symbol = try literalTree.decode(reader: &reader)
            switch symbol {
            case 0...255:
                try append(
                    UInt8(symbol),
                    to: &output,
                    maximumOutputSize: maximumOutputSize
                )
            case 256:
                return
            case 257...285:
                let lengthIndex = symbol - 257
                let length = lengthBases[lengthIndex]
                    + (try reader.readBits(lengthExtra[lengthIndex]))
                let distanceSymbol = try distanceTree.decode(reader: &reader)
                guard distanceSymbol < distanceBases.count else {
                    throw ZlibError.invalidData
                }
                let distance = distanceBases[distanceSymbol]
                    + (try reader.readBits(distanceExtra[distanceSymbol]))
                guard distance > 0, distance <= output.count,
                      output.count <= maximumOutputSize - length
                else {
                    throw distance > output.count
                        ? ZlibError.invalidData
                        : ZlibError.outputTooLarge
                }
                for _ in 0..<length {
                    output.append(output[output.count - distance])
                }
            default:
                throw ZlibError.invalidData
            }
        }
    }

    private static func append(
        _ byte: UInt8,
        to output: inout [UInt8],
        maximumOutputSize: Int
    ) throws {
        guard output.count < maximumOutputSize else {
            throw ZlibError.outputTooLarge
        }
        output.append(byte)
    }

    private static func append(
        _ bytes: [UInt8],
        to output: inout [UInt8],
        maximumOutputSize: Int
    ) throws {
        guard bytes.count <= maximumOutputSize - output.count else {
            throw ZlibError.outputTooLarge
        }
        output.append(contentsOf: bytes)
    }

    private static func adler32(_ bytes: [UInt8]) -> UInt32 {
        let modulus: UInt32 = 65_521
        var first: UInt32 = 1
        var second: UInt32 = 0
        for byte in bytes {
            first = (first + UInt32(byte)) % modulus
            second = (second + first) % modulus
        }
        return second << 16 | first
    }
}

private struct BitReader {
    let bytes: [UInt8]
    var byteIndex: Int
    var bitIndex = 0

    mutating func readBits(_ count: Int) throws -> Int {
        guard count >= 0, count <= 16 else { throw ZlibError.invalidData }
        var value = 0
        for index in 0..<count {
            guard byteIndex < bytes.count else { throw ZlibError.invalidData }
            value |= Int((bytes[byteIndex] >> bitIndex) & 1) << index
            bitIndex += 1
            if bitIndex == 8 {
                bitIndex = 0
                byteIndex += 1
            }
        }
        return value
    }

    mutating func alignToByte() throws {
        if bitIndex != 0 {
            bitIndex = 0
            byteIndex += 1
        }
        guard byteIndex <= bytes.count else { throw ZlibError.invalidData }
    }

    mutating func readUInt16() throws -> Int {
        guard bitIndex == 0, byteIndex <= bytes.count - 2 else {
            throw ZlibError.invalidData
        }
        defer { byteIndex += 2 }
        return Int(bytes[byteIndex]) | Int(bytes[byteIndex + 1]) << 8
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard bitIndex == 0, count >= 0, byteIndex <= bytes.count - count else {
            throw ZlibError.invalidData
        }
        defer { byteIndex += count }
        return Array(bytes[byteIndex..<(byteIndex + count)])
    }
}

private struct HuffmanTree {
    let entries: [Int: Int]
    let maximumLength: Int

    init(lengths: [Int]) throws {
        let maximumLength = lengths.max() ?? 0
        guard maximumLength > 0, maximumLength <= 15 else {
            throw ZlibError.invalidData
        }
        var counts = [Int](repeating: 0, count: maximumLength + 1)
        for length in lengths where length > 0 {
            guard length <= maximumLength else { throw ZlibError.invalidData }
            counts[length] += 1
        }
        var available = 1
        for length in 1...maximumLength {
            available = available * 2 - counts[length]
            guard available >= 0 else { throw ZlibError.invalidData }
        }

        var next = [Int](repeating: 0, count: maximumLength + 1)
        var code = 0
        if maximumLength > 1 {
            for length in 1..<maximumLength {
                code = (code + counts[length]) << 1
                next[length + 1] = code
            }
        }
        var entries: [Int: Int] = [:]
        for (symbol, length) in lengths.enumerated() where length > 0 {
            let reversed = reverse(next[length], bitCount: length)
            entries[length << 16 | reversed] = symbol
            next[length] += 1
        }
        self.entries = entries
        self.maximumLength = maximumLength
    }

    func decode(reader: inout BitReader) throws -> Int {
        var code = 0
        for length in 1...maximumLength {
            code |= try reader.readBits(1) << (length - 1)
            if let symbol = entries[length << 16 | code] {
                return symbol
            }
        }
        throw ZlibError.invalidData
    }

    static let fixedLiteral = try! HuffmanTree(
        lengths: (0..<288).map {
            switch $0 {
            case 0...143: 8
            case 144...255: 9
            case 256...279: 7
            default: 8
            }
        }
    )

    static let fixedDistance = try! HuffmanTree(
        lengths: [Int](repeating: 5, count: 32)
    )
}

private func reverse(_ value: Int, bitCount: Int) -> Int {
    var value = value
    var result = 0
    for _ in 0..<bitCount {
        result = result << 1 | value & 1
        value >>= 1
    }
    return result
}
