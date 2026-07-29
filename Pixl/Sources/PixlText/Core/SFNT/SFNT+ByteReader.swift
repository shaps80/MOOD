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
        
        func require(_ offset: Int, count: Int) throws {
            guard offset >= 0, count >= 0, offset <= bytes.count - count else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
        }
    }
}
