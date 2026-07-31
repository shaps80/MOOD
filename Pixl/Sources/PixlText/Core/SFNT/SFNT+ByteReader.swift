extension SFNT {
    struct ByteReader {
        let bytes: [UInt8]
        
        init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }
        
        func uint16(at offset: Int) throws -> UInt16 {
            try require(offset, count: 2)
            return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
        }
        
        func int16(at offset: Int) throws -> Int16 {
            Int16(bitPattern: try uint16(at: offset))
        }
        
        func uint32(at offset: Int) throws -> UInt32 {
            try require(offset, count: 4)
            return UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
        }

        func int32(at offset: Int) throws -> Int32 {
            Int32(bitPattern: try uint32(at: offset))
        }

        func uint8(at offset: Int) throws -> UInt8 {
            try require(offset, count: 1)
            return bytes[offset]
        }

        func fixed16_16(at offset: Int) throws -> Float {
            Float(try int32(at: offset)) / 65_536
        }

        func f2dot14(at offset: Int) throws -> Float {
            Float(try int16(at: offset)) / 16_384
        }
        
        func require(_ offset: Int, count: Int) throws {
            guard offset >= 0, count >= 0, offset <= bytes.count - count else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
        }
    }
}
