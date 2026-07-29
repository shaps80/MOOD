extension SFNT {
    enum CharacterMap {
        case format4(Format4)
        case format12(Format12)
        
        func glyphID(for scalar: UInt32, bytes: [UInt8]) -> UInt16? {
            switch self {
            case .format4(let format):
                return format.glyphID(for: scalar, bytes: bytes)
            case .format12(let format):
                return format.glyphID(for: scalar, bytes: bytes)
            }
        }
        
        struct Format4 {
            let offset: Int
            let segmentCount: Int
            
            func glyphID(for scalar: UInt32, bytes: [UInt8]) -> UInt16? {
                guard scalar <= UInt32(UInt16.max) else { return nil }
                let reader = ByteReader(bytes)
                let endCodes = offset + 14
                let startCodes = endCodes + segmentCount * 2 + 2
                let deltas = startCodes + segmentCount * 2
                let rangeOffsets = deltas + segmentCount * 2
                
                for index in 0..<segmentCount {
                    guard
                        let end = try? reader.uint16(at: endCodes + index * 2),
                        scalar <= UInt32(end),
                        let start = try? reader.uint16(at: startCodes + index * 2)
                            else { continue }
                    guard scalar >= UInt32(start) else { return nil }
                    
                    guard
                        let delta = try? reader.int16(at: deltas + index * 2),
                        let rangeOffset = try? reader.uint16(at: rangeOffsets + index * 2)
                            else { return nil }
                    
                    if rangeOffset == 0 {
                        let glyph = UInt16(truncatingIfNeeded: Int(scalar) + Int(delta))
                        return glyph == 0 ? nil : glyph
                    }
                    
                    let glyphOffset = rangeOffsets + index * 2
                    + Int(rangeOffset)
                    + (Int(scalar) - Int(start)) * 2
                    guard let rawGlyph = try? reader.uint16(at: glyphOffset), rawGlyph != 0 else {
                        return nil
                    }
                    return UInt16(truncatingIfNeeded: Int(rawGlyph) + Int(delta))
                }
                
                return nil
            }
        }
        
        struct Format12 {
            let offset: Int
            let groupCount: Int
            
            func glyphID(for scalar: UInt32, bytes: [UInt8]) -> UInt16? {
                let reader = ByteReader(bytes)
                var lower = 0
                var upper = groupCount
                
                while lower < upper {
                    let middle = lower + (upper - lower) / 2
                    let group = offset + 16 + middle * 12
                    guard
                        let start = try? reader.uint32(at: group),
                        let end = try? reader.uint32(at: group + 4)
                            else { return nil }
                    
                    if scalar < start {
                        upper = middle
                    } else if scalar > end {
                        lower = middle + 1
                    } else {
                        guard let firstGlyph = try? reader.uint32(at: group + 8) else { return nil }
                        let glyph = firstGlyph + scalar - start
                        guard glyph <= UInt32(UInt16.max), glyph != 0 else { return nil }
                        return UInt16(glyph)
                    }
                }
                
                return nil
            }
        }
    }
}
