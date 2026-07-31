extension SFNT {
    struct GlyphVariations {
        struct TupleHeader {
            let dataSize: Int
            let peak: [Float]
            let start: [Float]
            let end: [Float]
            let hasPrivatePoints: Bool
        }

        let table: Table
        let axisCount: Int
        let glyphDataOffset: Int
        let glyphOffsets: [Int]
        let sharedTuples: [[Float]]

        static func parse(
            table: Table?,
            expectedAxisCount: Int,
            glyphCount: Int,
            bytes: [UInt8]
        ) throws -> Self? {
            guard let table else { return nil }
            let reader = ByteReader(bytes)
            try require(table, at: table.offset, count: 20)
            guard try reader.uint16(at: table.offset) == 1,
                  try reader.uint16(at: table.offset + 2) == 0
            else { throw RegistrationError.malformedRequiredTable }
            let axisCount = Int(try reader.uint16(at: table.offset + 4))
            let sharedTupleCount = Int(try reader.uint16(at: table.offset + 6))
            let sharedTupleOffset = Int(try reader.uint32(at: table.offset + 8))
            let tableGlyphCount = Int(try reader.uint16(at: table.offset + 12))
            let flags = try reader.uint16(at: table.offset + 14)
            let glyphDataOffset = Int(try reader.uint32(at: table.offset + 16))
            guard axisCount == expectedAxisCount, tableGlyphCount == glyphCount else {
                throw RegistrationError.malformedRequiredTable
            }
            let longOffsets = flags & 1 != 0
            let offsetSize = longOffsets ? 4 : 2
            try require(
                table,
                at: table.offset + 20,
                count: try byteCount(glyphCount + 1, offsetSize)
            )
            var glyphOffsets: [Int] = []
            glyphOffsets.reserveCapacity(glyphCount + 1)
            var previous = 0
            for index in 0...glyphCount {
                let raw = longOffsets
                    ? Int(try reader.uint32(at: table.offset + 20 + index * 4))
                    : Int(try reader.uint16(at: table.offset + 20 + index * 2)) * 2
                guard raw >= previous else { throw RegistrationError.malformedRequiredTable }
                glyphOffsets.append(raw)
                previous = raw
            }
            guard glyphDataOffset <= table.length,
                  glyphOffsets.last.map({ $0 <= table.length - glyphDataOffset }) == true
            else { throw RegistrationError.malformedRequiredTable }

            let tuplesStart = table.offset + sharedTupleOffset
            try require(
                table,
                at: tuplesStart,
                count: try byteCount(try byteCount(sharedTupleCount, axisCount), 2)
            )
            var sharedTuples: [[Float]] = []
            sharedTuples.reserveCapacity(sharedTupleCount)
            var cursor = tuplesStart
            for _ in 0..<sharedTupleCount {
                var tuple: [Float] = []
                tuple.reserveCapacity(axisCount)
                for _ in 0..<axisCount {
                    tuple.append(try reader.f2dot14(at: cursor))
                    cursor += 2
                }
                sharedTuples.append(tuple)
            }
            return .init(
                table: table,
                axisCount: axisCount,
                glyphDataOffset: glyphDataOffset,
                glyphOffsets: glyphOffsets,
                sharedTuples: sharedTuples
            )
        }

        func apply(
            glyph: GlyphID,
            to outline: inout TrueTypeOutlines.Outline,
            coordinates: [Float],
            bytes: [UInt8]
        ) {
            let glyphIndex = Int(glyph.rawValue)
            guard glyphOffsets.indices.contains(glyphIndex + 1),
                  coordinates.count == axisCount
            else { return }
            let relativeStart = glyphOffsets[glyphIndex]
            let relativeEnd = glyphOffsets[glyphIndex + 1]
            guard relativeStart < relativeEnd else { return }
            let reader = ByteReader(bytes)
            let start = table.offset + glyphDataOffset + relativeStart
            let end = table.offset + glyphDataOffset + relativeEnd
            guard end - start >= 4,
                  let rawCount = try? reader.uint16(at: start),
                  let dataOffset = try? reader.uint16(at: start + 2)
            else { return }
            let tupleCount = Int(rawCount & 0x0FFF)
            let hasSharedPoints = rawCount & 0x8000 != 0
            var headerCursor = start + 4
            var headers: [TupleHeader] = []
            headers.reserveCapacity(tupleCount)
            for _ in 0..<tupleCount {
                guard let header = parseHeader(
                    cursor: &headerCursor,
                    limit: end,
                    reader: reader
                ) else { return }
                headers.append(header)
            }
            var dataCursor = start + Int(dataOffset)
            guard dataCursor >= headerCursor, dataCursor <= end else { return }
            let pointCount = outline.points.count + 4
            let sharedPoints: [Int]?
            if hasSharedPoints {
                guard let decoded = unpackPoints(
                    cursor: &dataCursor,
                    limit: end,
                    reader: reader,
                    pointCount: pointCount
                ) else { return }
                sharedPoints = decoded.points
            } else {
                sharedPoints = nil
            }

            let original = outline.points
            for header in headers {
                let tupleEnd = dataCursor + header.dataSize
                guard tupleEnd >= dataCursor, tupleEnd <= end else { return }
                let scalar = tupleScalar(header, coordinates: coordinates)
                if scalar == 0 {
                    dataCursor = tupleEnd
                    continue
                }
                let points: [Int]?
                if header.hasPrivatePoints {
                    guard let decoded = unpackPoints(
                        cursor: &dataCursor,
                        limit: tupleEnd,
                        reader: reader,
                        pointCount: pointCount
                    ) else { return }
                    points = decoded.points
                } else {
                    points = sharedPoints
                }
                let deltaCount = points?.count ?? pointCount
                guard let xDeltas = unpackDeltas(
                    count: deltaCount,
                    cursor: &dataCursor,
                    limit: tupleEnd,
                    reader: reader
                ), let yDeltas = unpackDeltas(
                    count: deltaCount,
                    cursor: &dataCursor,
                    limit: tupleEnd,
                    reader: reader
                ) else { return }
                dataCursor = tupleEnd

                var x = Array<Float?>(repeating: nil, count: outline.points.count)
                var y = Array<Float?>(repeating: nil, count: outline.points.count)
                if let points {
                    for index in points.indices where points[index] < outline.points.count {
                        x[points[index]] = Float(xDeltas[index])
                        y[points[index]] = Float(yDeltas[index])
                    }
                    interpolate(
                        deltas: &x,
                        original: original.map(\.x),
                        contourEnds: outline.contourEnds
                    )
                    interpolate(
                        deltas: &y,
                        original: original.map(\.y),
                        contourEnds: outline.contourEnds
                    )
                } else {
                    for index in outline.points.indices {
                        x[index] = Float(xDeltas[index])
                        y[index] = Float(yDeltas[index])
                    }
                }
                for index in outline.points.indices {
                    outline.points[index].x += (x[index] ?? 0) * scalar
                    outline.points[index].y += (y[index] ?? 0) * scalar
                }
            }
        }

        func componentDeltas(
            glyph: GlyphID,
            componentCount: Int,
            coordinates: [Float],
            bytes: [UInt8]
        ) -> [(x: Float, y: Float)]? {
            let pointCount = componentCount + 4
            guard componentCount > 0,
                  let data = variationData(for: glyph, coordinates: coordinates, bytes: bytes)
            else { return nil }
            let reader = ByteReader(bytes)
            var dataCursor = data.dataStart
            let sharedPoints: [Int]?
            if data.hasSharedPoints {
                guard let decoded = unpackPoints(
                    cursor: &dataCursor,
                    limit: data.end,
                    reader: reader,
                    pointCount: pointCount
                ) else { return nil }
                sharedPoints = decoded.points
            } else {
                sharedPoints = nil
            }
            var result = Array(repeating: (x: Float(0), y: Float(0)), count: componentCount)
            for header in data.headers {
                let tupleEnd = dataCursor + header.dataSize
                guard tupleEnd >= dataCursor, tupleEnd <= data.end else { return nil }
                let points: [Int]?
                if header.hasPrivatePoints {
                    guard let decoded = unpackPoints(
                        cursor: &dataCursor,
                        limit: tupleEnd,
                        reader: reader,
                        pointCount: pointCount
                    ) else { return nil }
                    points = decoded.points
                } else {
                    points = sharedPoints
                }
                let deltaCount = points?.count ?? pointCount
                guard let xDeltas = unpackDeltas(
                    count: deltaCount,
                    cursor: &dataCursor,
                    limit: tupleEnd,
                    reader: reader
                ), let yDeltas = unpackDeltas(
                    count: deltaCount,
                    cursor: &dataCursor,
                    limit: tupleEnd,
                    reader: reader
                ) else { return nil }
                dataCursor = tupleEnd
                let scalar = tupleScalar(header, coordinates: coordinates)
                guard scalar != 0 else { continue }
                if let points {
                    for deltaIndex in points.indices {
                        let pointIndex = points[deltaIndex]
                        guard pointIndex < componentCount else { continue }
                        result[pointIndex].x += Float(xDeltas[deltaIndex]) * scalar
                        result[pointIndex].y += Float(yDeltas[deltaIndex]) * scalar
                    }
                } else {
                    for pointIndex in 0..<componentCount {
                        result[pointIndex].x += Float(xDeltas[pointIndex]) * scalar
                        result[pointIndex].y += Float(yDeltas[pointIndex]) * scalar
                    }
                }
            }
            return result
        }

        private func variationData(
            for glyph: GlyphID,
            coordinates: [Float],
            bytes: [UInt8]
        ) -> (headers: [TupleHeader], dataStart: Int, end: Int, hasSharedPoints: Bool)? {
            let glyphIndex = Int(glyph.rawValue)
            guard glyphOffsets.indices.contains(glyphIndex + 1),
                  coordinates.count == axisCount
            else { return nil }
            let relativeStart = glyphOffsets[glyphIndex]
            let relativeEnd = glyphOffsets[glyphIndex + 1]
            guard relativeStart < relativeEnd else { return nil }
            let reader = ByteReader(bytes)
            let start = table.offset + glyphDataOffset + relativeStart
            let end = table.offset + glyphDataOffset + relativeEnd
            guard end - start >= 4,
                  let rawCount = try? reader.uint16(at: start),
                  let dataOffset = try? reader.uint16(at: start + 2)
            else { return nil }
            let tupleCount = Int(rawCount & 0x0FFF)
            var headerCursor = start + 4
            var headers: [TupleHeader] = []
            headers.reserveCapacity(tupleCount)
            for _ in 0..<tupleCount {
                guard let header = parseHeader(cursor: &headerCursor, limit: end, reader: reader) else {
                    return nil
                }
                headers.append(header)
            }
            let dataStart = start + Int(dataOffset)
            guard dataStart >= headerCursor, dataStart <= end else { return nil }
            return (headers, dataStart, end, rawCount & 0x8000 != 0)
        }

        private func parseHeader(
            cursor: inout Int,
            limit: Int,
            reader: ByteReader
        ) -> TupleHeader? {
            guard cursor <= limit - 4,
                  let dataSize = try? reader.uint16(at: cursor),
                  let tupleIndex = try? reader.uint16(at: cursor + 2)
            else { return nil }
            cursor += 4
            let embeddedPeak = tupleIndex & 0x8000 != 0
            let hasIntermediate = tupleIndex & 0x4000 != 0
            let hasPrivatePoints = tupleIndex & 0x2000 != 0
            let peak: [Float]
            if embeddedPeak {
                guard let tuple = readTuple(cursor: &cursor, limit: limit, reader: reader) else {
                    return nil
                }
                peak = tuple
            } else {
                let index = Int(tupleIndex & 0x0FFF)
                guard sharedTuples.indices.contains(index) else { return nil }
                peak = sharedTuples[index]
            }
            let start: [Float]
            let end: [Float]
            if hasIntermediate {
                guard let lower = readTuple(cursor: &cursor, limit: limit, reader: reader),
                      let upper = readTuple(cursor: &cursor, limit: limit, reader: reader)
                else { return nil }
                start = lower
                end = upper
            } else {
                start = peak.map { $0 < 0 ? -1 : 0 }
                end = peak.map { $0 > 0 ? 1 : 0 }
            }
            return .init(
                dataSize: Int(dataSize),
                peak: peak,
                start: start,
                end: end,
                hasPrivatePoints: hasPrivatePoints
            )
        }

        private func readTuple(
            cursor: inout Int,
            limit: Int,
            reader: ByteReader
        ) -> [Float]? {
            guard cursor <= limit - axisCount * 2 else { return nil }
            var result: [Float] = []
            result.reserveCapacity(axisCount)
            for _ in 0..<axisCount {
                guard let value = try? reader.f2dot14(at: cursor) else { return nil }
                result.append(value)
                cursor += 2
            }
            return result
        }

        private func tupleScalar(_ header: TupleHeader, coordinates: [Float]) -> Float {
            var scalar: Float = 1
            for index in coordinates.indices {
                let coordinate = coordinates[index]
                let peak = header.peak[index]
                let start = header.start[index]
                let end = header.end[index]
                if peak == 0 { continue }
                if coordinate < start || coordinate > end { return 0 }
                if coordinate == peak { continue }
                if coordinate < peak {
                    guard peak != start else { return 0 }
                    scalar *= (coordinate - start) / (peak - start)
                } else {
                    guard end != peak else { return 0 }
                    scalar *= (end - coordinate) / (end - peak)
                }
            }
            return scalar
        }

        private func unpackPoints(
            cursor: inout Int,
            limit: Int,
            reader: ByteReader,
            pointCount: Int
        ) -> (points: [Int]?, count: Int)? {
            guard cursor < limit, let first = try? reader.uint8(at: cursor) else { return nil }
            cursor += 1
            var count = Int(first)
            if first & 0x80 != 0 {
                guard cursor < limit, let second = try? reader.uint8(at: cursor) else { return nil }
                cursor += 1
                count = Int(first & 0x7F) << 8 | Int(second)
            }
            if count == 0 { return (nil, pointCount) }
            guard count <= pointCount else { return nil }
            var points: [Int] = []
            points.reserveCapacity(count)
            var current = 0
            while points.count < count {
                guard cursor < limit, let control = try? reader.uint8(at: cursor) else { return nil }
                cursor += 1
                let runCount = Int(control & 0x7F) + 1
                guard runCount <= count - points.count else { return nil }
                let words = control & 0x80 != 0
                for _ in 0..<runCount {
                    let delta: Int
                    if words {
                        guard cursor <= limit - 2,
                              let value = try? reader.uint16(at: cursor) else { return nil }
                        cursor += 2
                        delta = Int(value)
                    } else {
                        guard cursor < limit,
                              let value = try? reader.uint8(at: cursor) else { return nil }
                        cursor += 1
                        delta = Int(value)
                    }
                    current += delta
                    guard current < pointCount else { return nil }
                    points.append(current)
                }
            }
            return (points, count)
        }

        private func unpackDeltas(
            count: Int,
            cursor: inout Int,
            limit: Int,
            reader: ByteReader
        ) -> [Int16]? {
            var result: [Int16] = []
            result.reserveCapacity(count)
            while result.count < count {
                guard cursor < limit, let control = try? reader.uint8(at: cursor) else { return nil }
                cursor += 1
                let runCount = Int(control & 0x3F) + 1
                guard runCount <= count - result.count else { return nil }
                if control & 0x80 != 0 {
                    result.append(contentsOf: repeatElement(0, count: runCount))
                } else if control & 0x40 != 0 {
                    guard cursor <= limit - runCount * 2 else { return nil }
                    for _ in 0..<runCount {
                        guard let value = try? reader.int16(at: cursor) else { return nil }
                        result.append(value)
                        cursor += 2
                    }
                } else {
                    guard cursor <= limit - runCount else { return nil }
                    for _ in 0..<runCount {
                        guard let value = try? reader.uint8(at: cursor) else { return nil }
                        result.append(Int16(Int8(bitPattern: value)))
                        cursor += 1
                    }
                }
            }
            return result
        }

        private func interpolate(
            deltas: inout [Float?],
            original: [Float],
            contourEnds: [Int]
        ) {
            var contourStart = 0
            for contourEnd in contourEnds {
                guard contourStart <= contourEnd, contourEnd < deltas.count else { return }
                let touched = (contourStart...contourEnd).filter { deltas[$0] != nil }
                if touched.count == 1 {
                    let value = deltas[touched[0]]!
                    for index in contourStart...contourEnd { deltas[index] = value }
                } else if touched.count > 1 {
                    for touchedIndex in touched.indices {
                        let lower = touched[touchedIndex]
                        let upper = touched[(touchedIndex + 1) % touched.count]
                        var index = lower
                        repeat {
                            index = index == contourEnd ? contourStart : index + 1
                            guard index != upper else { break }
                            deltas[index] = interpolateDelta(
                                coordinate: original[index],
                                lowerCoordinate: original[lower],
                                lowerDelta: deltas[lower]!,
                                upperCoordinate: original[upper],
                                upperDelta: deltas[upper]!
                            )
                        } while index != lower
                    }
                }
                contourStart = contourEnd + 1
            }
        }

        private func interpolateDelta(
            coordinate: Float,
            lowerCoordinate: Float,
            lowerDelta: Float,
            upperCoordinate: Float,
            upperDelta: Float
        ) -> Float {
            if lowerCoordinate == upperCoordinate { return lowerDelta }
            let minimumCoordinate = min(lowerCoordinate, upperCoordinate)
            let maximumCoordinate = max(lowerCoordinate, upperCoordinate)
            if coordinate <= minimumCoordinate {
                return lowerCoordinate < upperCoordinate ? lowerDelta : upperDelta
            }
            if coordinate >= maximumCoordinate {
                return lowerCoordinate > upperCoordinate ? lowerDelta : upperDelta
            }
            let amount = (coordinate - lowerCoordinate) / (upperCoordinate - lowerCoordinate)
            return lowerDelta + (upperDelta - lowerDelta) * amount
        }

        private static func require(_ table: Table, at offset: Int, count: Int) throws {
            guard offset >= table.offset, count >= 0,
                  offset <= table.offset + table.length - count
            else { throw RegistrationError.malformedRequiredTable }
        }

        private static func byteCount(_ lhs: Int, _ rhs: Int) throws -> Int {
            let result = lhs.multipliedReportingOverflow(by: rhs)
            guard !result.overflow else { throw RegistrationError.malformedRequiredTable }
            return result.partialValue
        }
    }
}
