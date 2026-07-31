extension SFNT {
    struct ItemVariationStore {
        struct RegionAxis: Hashable {
            let start: Float
            let peak: Float
            let end: Float
        }

        struct Data: Hashable {
            let regionIndices: [UInt16]
            let deltas: [Int32]
            let itemCount: Int

            var regionCount: Int { regionIndices.count }
        }

        let regions: [[RegionAxis]]
        let data: [Data]

        static func parse(at offset: Int, table: Table, reader: ByteReader) throws -> Self {
            try require(table, at: offset, count: 8)
            guard try reader.uint16(at: offset) == 1 else {
                throw RegistrationError.malformedRequiredTable
            }
            let regionListOffset = Int(try reader.uint32(at: offset + 2))
            let dataCount = Int(try reader.uint16(at: offset + 6))
            try require(table, at: offset + 8, count: try byteCount(dataCount, 4))

            let regionList = offset + regionListOffset
            try require(table, at: regionList, count: 4)
            let axisCount = Int(try reader.uint16(at: regionList))
            let regionCount = Int(try reader.uint16(at: regionList + 2))
            let regionByteCount = try byteCount(try byteCount(axisCount, regionCount), 6)
            try require(table, at: regionList + 4, count: regionByteCount)
            var regions: [[RegionAxis]] = []
            regions.reserveCapacity(regionCount)
            var regionOffset = regionList + 4
            for _ in 0..<regionCount {
                var axes: [RegionAxis] = []
                axes.reserveCapacity(axisCount)
                for _ in 0..<axisCount {
                    let start = try reader.f2dot14(at: regionOffset)
                    let peak = try reader.f2dot14(at: regionOffset + 2)
                    let end = try reader.f2dot14(at: regionOffset + 4)
                    guard start <= peak, peak <= end else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    axes.append(.init(start: start, peak: peak, end: end))
                    regionOffset += 6
                }
                regions.append(axes)
            }

            var data: [Data] = []
            data.reserveCapacity(dataCount)
            for index in 0..<dataCount {
                let relativeOffset = Int(try reader.uint32(at: offset + 8 + index * 4))
                let dataOffset = offset + relativeOffset
                try require(table, at: dataOffset, count: 6)
                let itemCount = Int(try reader.uint16(at: dataOffset))
                let rawWordDeltaCount = try reader.uint16(at: dataOffset + 2)
                let usesLongWords = rawWordDeltaCount & 0x8000 != 0
                let wordDeltaCount = Int(rawWordDeltaCount & 0x7FFF)
                let regionIndexCount = Int(try reader.uint16(at: dataOffset + 4))
                guard wordDeltaCount <= regionIndexCount else {
                    throw RegistrationError.malformedRequiredTable
                }
                try require(table, at: dataOffset + 6, count: try byteCount(regionIndexCount, 2))
                var regionIndices: [UInt16] = []
                regionIndices.reserveCapacity(regionIndexCount)
                for regionIndex in 0..<regionIndexCount {
                    let value = try reader.uint16(at: dataOffset + 6 + regionIndex * 2)
                    guard Int(value) < regionCount else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    regionIndices.append(value)
                }
                var cursor = dataOffset + 6 + regionIndexCount * 2
                var deltas: [Int32] = []
                deltas.reserveCapacity(try byteCount(itemCount, regionIndexCount))
                for _ in 0..<itemCount {
                    for deltaIndex in 0..<regionIndexCount {
                        let isWord = deltaIndex < wordDeltaCount
                        let value: Int32
                        if usesLongWords {
                            if isWord {
                                value = try reader.int32(at: cursor)
                                cursor += 4
                            } else {
                                value = Int32(try reader.int16(at: cursor))
                                cursor += 2
                            }
                        } else if isWord {
                            value = Int32(try reader.int16(at: cursor))
                            cursor += 2
                        } else {
                            value = Int32(Int8(bitPattern: try reader.uint8(at: cursor)))
                            cursor += 1
                        }
                        deltas.append(value)
                    }
                }
                try require(table, at: dataOffset, count: cursor - dataOffset)
                data.append(.init(
                    regionIndices: regionIndices,
                    deltas: deltas,
                    itemCount: itemCount
                ))
            }
            return .init(regions: regions, data: data)
        }

        func delta(outer: Int, inner: Int, coordinates: [Float]) -> Float {
            guard data.indices.contains(outer) else { return 0 }
            let table = data[outer]
            guard inner >= 0, inner < table.itemCount else { return 0 }
            var result: Float = 0
            let base = inner * table.regionCount
            for index in table.regionIndices.indices {
                let regionIndex = Int(table.regionIndices[index])
                let scalar = regionScalar(regions[regionIndex], coordinates: coordinates)
                result += Float(table.deltas[base + index]) * scalar
            }
            return result
        }

        private func regionScalar(_ axes: [RegionAxis], coordinates: [Float]) -> Float {
            guard axes.count == coordinates.count else { return 0 }
            var scalar: Float = 1
            for index in axes.indices {
                let axis = axes[index]
                let coordinate = coordinates[index]
                if axis.peak == 0 || axis.start > axis.peak || axis.peak > axis.end {
                    continue
                }
                if coordinate < axis.start || coordinate > axis.end { return 0 }
                if coordinate == axis.peak { continue }
                if coordinate < axis.peak {
                    guard axis.peak != axis.start else { return 0 }
                    scalar *= (coordinate - axis.start) / (axis.peak - axis.start)
                } else {
                    guard axis.end != axis.peak else { return 0 }
                    scalar *= (axis.end - coordinate) / (axis.end - axis.peak)
                }
            }
            return scalar
        }

        private static func require(
            _ table: Table,
            at offset: Int,
            count: Int
        ) throws {
            guard offset >= table.offset,
                  count >= 0,
                  offset <= table.offset + table.length - count
            else { throw RegistrationError.malformedRequiredTable }
        }

        private static func byteCount(_ lhs: Int, _ rhs: Int) throws -> Int {
            let result = lhs.multipliedReportingOverflow(by: rhs)
            guard !result.overflow, result.partialValue >= 0 else {
                throw RegistrationError.malformedRequiredTable
            }
            return result.partialValue
        }
    }
}
