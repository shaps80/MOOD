extension SFNT {
    struct TrueTypeOutlines {
        struct Point: Hashable {
            var x: Float
            var y: Float
            let onCurve: Bool
        }

        struct Outline: Hashable {
            var points: [Point]
            var contourEnds: [Int]
        }

        private struct Component {
            let flags: UInt16
            let glyph: GlyphID
            let argument1: Int
            let argument2: Int
            let xx: Float
            let yx: Float
            let xy: Float
            let yy: Float
        }

        let locations: Table
        let glyphs: Table
        let locationFormat: Int16

        func bounds(for glyph: GlyphID, bytes: [UInt8]) -> GlyphBounds? {
            let index = Int(glyph.rawValue)
            let reader = ByteReader(bytes)

            guard
                let start = try? glyphOffset(at: index, reader: reader),
                let end = try? glyphOffset(at: index + 1, reader: reader),
                start < end,
                start >= 0,
                end <= glyphs.length,
                start <= glyphs.length - 10
            else {
                return nil
            }

            let offset = glyphs.offset + start
            guard
                let xMin = try? reader.int16(at: offset + 2),
                let yMin = try? reader.int16(at: offset + 4),
                let xMax = try? reader.int16(at: offset + 6),
                let yMax = try? reader.int16(at: offset + 8)
            else {
                return nil
            }

            return .init(xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax)
        }

        func simpleOutline(for glyph: GlyphID, bytes: [UInt8]) -> Outline? {
            let reader = ByteReader(bytes)
            guard let range = glyphRange(for: glyph, reader: reader), range.count >= 10 else {
                return nil
            }
            let offset = glyphs.offset + range.lowerBound
            guard let contourCount = try? reader.int16(at: offset), contourCount >= 0 else {
                return nil
            }
            let count = Int(contourCount)
            var cursor = offset + 10
            guard range.count >= 10 + count * 2 else { return nil }
            var contourEnds: [Int] = []
            contourEnds.reserveCapacity(count)
            var previous = -1
            for _ in 0..<count {
                guard let raw = try? reader.uint16(at: cursor) else { return nil }
                let end = Int(raw)
                guard end > previous else { return nil }
                contourEnds.append(end)
                previous = end
                cursor += 2
            }
            let pointCount = (contourEnds.last ?? -1) + 1
            guard let instructionLength = try? reader.uint16(at: cursor) else { return nil }
            cursor += 2 + Int(instructionLength)
            guard cursor <= glyphs.offset + range.upperBound else { return nil }

            var flags: [UInt8] = []
            flags.reserveCapacity(pointCount)
            while flags.count < pointCount {
                guard let flag = try? reader.uint8(at: cursor) else { return nil }
                cursor += 1
                let repetitions: Int
                if flag & 0x08 != 0 {
                    guard let repeatCount = try? reader.uint8(at: cursor) else { return nil }
                    cursor += 1
                    repetitions = Int(repeatCount) + 1
                } else {
                    repetitions = 1
                }
                guard repetitions <= pointCount - flags.count else { return nil }
                flags.append(contentsOf: repeatElement(flag, count: repetitions))
            }

            var xs = Array(repeating: Float(0), count: pointCount)
            var x: Int32 = 0
            for index in 0..<pointCount {
                let flag = flags[index]
                let delta: Int32
                if flag & 0x02 != 0 {
                    guard let value = try? reader.uint8(at: cursor) else { return nil }
                    cursor += 1
                    delta = flag & 0x10 != 0 ? Int32(value) : -Int32(value)
                } else if flag & 0x10 != 0 {
                    delta = 0
                } else {
                    guard let value = try? reader.int16(at: cursor) else { return nil }
                    cursor += 2
                    delta = Int32(value)
                }
                x += delta
                xs[index] = Float(x)
            }

            var points: [Point] = []
            points.reserveCapacity(pointCount)
            var y: Int32 = 0
            for index in 0..<pointCount {
                let flag = flags[index]
                let delta: Int32
                if flag & 0x04 != 0 {
                    guard let value = try? reader.uint8(at: cursor) else { return nil }
                    cursor += 1
                    delta = flag & 0x20 != 0 ? Int32(value) : -Int32(value)
                } else if flag & 0x20 != 0 {
                    delta = 0
                } else {
                    guard let value = try? reader.int16(at: cursor) else { return nil }
                    cursor += 2
                    delta = Int32(value)
                }
                y += delta
                points.append(.init(x: xs[index], y: Float(y), onCurve: flag & 0x01 != 0))
            }
            guard cursor <= glyphs.offset + range.upperBound else { return nil }
            return .init(points: points, contourEnds: contourEnds)
        }

        func variedOutline(
            for glyph: GlyphID,
            variations: GlyphVariations?,
            coordinates: [Float],
            bytes: [UInt8]
        ) -> Outline? {
            variedOutline(
                for: glyph,
                variations: variations,
                coordinates: coordinates,
                bytes: bytes,
                depth: 0
            )
        }

        private func variedOutline(
            for glyph: GlyphID,
            variations: GlyphVariations?,
            coordinates: [Float],
            bytes: [UInt8],
            depth: Int
        ) -> Outline? {
            guard depth < 32 else { return nil }
            if var outline = simpleOutline(for: glyph, bytes: bytes) {
                variations?.apply(
                    glyph: glyph,
                    to: &outline,
                    coordinates: coordinates,
                    bytes: bytes
                )
                return outline
            }
            guard let components = compositeComponents(for: glyph, bytes: bytes) else {
                return nil
            }
            let componentDeltas = variations?.componentDeltas(
                glyph: glyph,
                componentCount: components.count,
                coordinates: coordinates,
                bytes: bytes
            )
            var result = Outline(points: [], contourEnds: [])
            for index in components.indices {
                let component = components[index]
                guard var child = variedOutline(
                    for: component.glyph,
                    variations: variations,
                    coordinates: coordinates,
                    bytes: bytes,
                    depth: depth + 1
                ) else { return nil }

                for pointIndex in child.points.indices {
                    let point = child.points[pointIndex]
                    child.points[pointIndex].x = component.xx * point.x + component.xy * point.y
                    child.points[pointIndex].y = component.yx * point.x + component.yy * point.y
                }

                var translationX: Float
                var translationY: Float
                if component.flags & 0x0002 != 0 {
                    translationX = Float(component.argument1)
                    translationY = Float(component.argument2)
                    if let componentDeltas {
                        translationX += componentDeltas[index].x
                        translationY += componentDeltas[index].y
                    }
                    if component.flags & 0x0800 != 0 {
                        let x = component.xx * translationX + component.xy * translationY
                        let y = component.yx * translationX + component.yy * translationY
                        translationX = x
                        translationY = y
                    }
                    if component.flags & 0x0004 != 0 {
                        translationX.round()
                        translationY.round()
                    }
                } else {
                    guard result.points.indices.contains(component.argument1),
                          child.points.indices.contains(component.argument2)
                    else { return nil }
                    translationX = result.points[component.argument1].x
                        - child.points[component.argument2].x
                    translationY = result.points[component.argument1].y
                        - child.points[component.argument2].y
                    if let componentDeltas {
                        translationX += componentDeltas[index].x
                        translationY += componentDeltas[index].y
                    }
                }

                let pointOffset = result.points.count
                for pointIndex in child.points.indices {
                    child.points[pointIndex].x += translationX
                    child.points[pointIndex].y += translationY
                }
                result.points.append(contentsOf: child.points)
                result.contourEnds.append(contentsOf: child.contourEnds.map { $0 + pointOffset })
            }
            return result
        }

        private func compositeComponents(for glyph: GlyphID, bytes: [UInt8]) -> [Component]? {
            let reader = ByteReader(bytes)
            guard let range = glyphRange(for: glyph, reader: reader), range.count >= 10 else {
                return nil
            }
            let start = glyphs.offset + range.lowerBound
            let limit = glyphs.offset + range.upperBound
            guard let contourCount = try? reader.int16(at: start), contourCount < 0 else {
                return nil
            }
            var cursor = start + 10
            var components: [Component] = []
            repeat {
                guard cursor <= limit - 4,
                      let flags = try? reader.uint16(at: cursor),
                      let rawGlyph = try? reader.uint16(at: cursor + 2)
                else { return nil }
                cursor += 4
                let argumentsAreWords = flags & 0x0001 != 0
                let argumentsAreXY = flags & 0x0002 != 0
                let argument1: Int
                let argument2: Int
                if argumentsAreWords {
                    guard cursor <= limit - 4 else { return nil }
                    if argumentsAreXY {
                        guard let first = try? reader.int16(at: cursor),
                              let second = try? reader.int16(at: cursor + 2)
                        else { return nil }
                        argument1 = Int(first)
                        argument2 = Int(second)
                    } else {
                        guard let first = try? reader.uint16(at: cursor),
                              let second = try? reader.uint16(at: cursor + 2)
                        else { return nil }
                        argument1 = Int(first)
                        argument2 = Int(second)
                    }
                    cursor += 4
                } else {
                    guard cursor <= limit - 2,
                          let first = try? reader.uint8(at: cursor),
                          let second = try? reader.uint8(at: cursor + 1)
                    else { return nil }
                    argument1 = argumentsAreXY ? Int(Int8(bitPattern: first)) : Int(first)
                    argument2 = argumentsAreXY ? Int(Int8(bitPattern: second)) : Int(second)
                    cursor += 2
                }

                var xx: Float = 1
                var yx: Float = 0
                var xy: Float = 0
                var yy: Float = 1
                if flags & 0x0008 != 0 {
                    guard cursor <= limit - 2, let scale = try? reader.f2dot14(at: cursor) else {
                        return nil
                    }
                    xx = scale
                    yy = scale
                    cursor += 2
                } else if flags & 0x0040 != 0 {
                    guard cursor <= limit - 4,
                          let xScale = try? reader.f2dot14(at: cursor),
                          let yScale = try? reader.f2dot14(at: cursor + 2)
                    else { return nil }
                    xx = xScale
                    yy = yScale
                    cursor += 4
                } else if flags & 0x0080 != 0 {
                    guard cursor <= limit - 8,
                          let valueXX = try? reader.f2dot14(at: cursor),
                          let valueXY = try? reader.f2dot14(at: cursor + 2),
                          let valueYX = try? reader.f2dot14(at: cursor + 4),
                          let valueYY = try? reader.f2dot14(at: cursor + 6)
                    else { return nil }
                    xx = valueXX
                    yx = valueYX
                    xy = valueXY
                    yy = valueYY
                    cursor += 8
                }
                components.append(.init(
                    flags: flags,
                    glyph: .init(rawValue: rawGlyph),
                    argument1: argument1,
                    argument2: argument2,
                    xx: xx,
                    yx: yx,
                    xy: xy,
                    yy: yy
                ))
                if flags & 0x0020 == 0 {
                    if flags & 0x0100 != 0 {
                        guard cursor <= limit - 2,
                              let instructionLength = try? reader.uint16(at: cursor),
                              Int(instructionLength) <= limit - cursor - 2
                        else { return nil }
                    }
                    break
                }
            } while components.count <= Int(UInt16.max)
            return components.isEmpty ? nil : components
        }

        func glyphRange(for glyph: GlyphID, reader: ByteReader) -> Range<Int>? {
            let index = Int(glyph.rawValue)
            guard let start = try? glyphOffset(at: index, reader: reader),
                  let end = try? glyphOffset(at: index + 1, reader: reader),
                  start >= 0, start <= end, end <= glyphs.length
            else { return nil }
            return start..<end
        }

        func bounds(of outline: Outline) -> GlyphBounds? {
            guard !outline.points.isEmpty else { return nil }
            var xMin = Float.greatestFiniteMagnitude
            var yMin = Float.greatestFiniteMagnitude
            var xMax = -Float.greatestFiniteMagnitude
            var yMax = -Float.greatestFiniteMagnitude
            func include(_ point: Point) {
                xMin = min(xMin, point.x)
                yMin = min(yMin, point.y)
                xMax = max(xMax, point.x)
                yMax = max(yMax, point.y)
            }
            func includeQuadratic(_ start: Point, _ control: Point, _ end: Point) {
                include(start)
                include(end)
                let denominatorX = start.x - 2 * control.x + end.x
                if denominatorX != 0 {
                    let t = (start.x - control.x) / denominatorX
                    if t > 0, t < 1 {
                        let value = (1 - t) * (1 - t) * start.x
                            + 2 * (1 - t) * t * control.x
                            + t * t * end.x
                        xMin = min(xMin, value)
                        xMax = max(xMax, value)
                    }
                }
                let denominatorY = start.y - 2 * control.y + end.y
                if denominatorY != 0 {
                    let t = (start.y - control.y) / denominatorY
                    if t > 0, t < 1 {
                        let value = (1 - t) * (1 - t) * start.y
                            + 2 * (1 - t) * t * control.y
                            + t * t * end.y
                        yMin = min(yMin, value)
                        yMax = max(yMax, value)
                    }
                }
            }

            var lower = 0
            for upper in outline.contourEnds {
                guard lower <= upper, upper < outline.points.count else { return nil }
                let contourCount = upper - lower + 1
                let first = outline.points[lower]
                let last = outline.points[upper]
                var current: Point
                var index: Int
                if first.onCurve {
                    current = first
                    index = 1
                } else if last.onCurve {
                    current = last
                    index = 0
                } else {
                    current = .init(
                        x: (last.x + first.x) * 0.5,
                        y: (last.y + first.y) * 0.5,
                        onCurve: true
                    )
                    index = 0
                }
                include(current)
                while index < contourCount {
                    let point = outline.points[lower + index]
                    if point.onCurve {
                        include(point)
                        current = point
                        index += 1
                    } else {
                        let next = outline.points[lower + (index + 1) % contourCount]
                        let end = next.onCurve ? next : .init(
                            x: (point.x + next.x) * 0.5,
                            y: (point.y + next.y) * 0.5,
                            onCurve: true
                        )
                        includeQuadratic(current, point, end)
                        current = end
                        index += next.onCurve ? 2 : 1
                    }
                }
                lower = upper + 1
            }
            guard xMin <= xMax, yMin <= yMax else { return nil }
            return .init(
                xMin: clampedInt16(xMin.rounded(.down)),
                yMin: clampedInt16(yMin.rounded(.down)),
                xMax: clampedInt16(xMax.rounded(.up)),
                yMax: clampedInt16(yMax.rounded(.up))
            )
        }

        private func clampedInt16(_ value: Float) -> Int16 {
            Int16(min(Float(Int16.max), max(Float(Int16.min), value)))
        }

        private func glyphOffset(at index: Int, reader: ByteReader) throws -> Int {
            switch locationFormat {
            case 0:
                return Int(try reader.uint16(at: locations.offset + index * 2)) * 2
            case 1:
                return Int(try reader.uint32(at: locations.offset + index * 4))
            default:
                throw RegistrationError.malformedRequiredTable
            }
        }
    }
}
