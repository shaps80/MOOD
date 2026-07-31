extension SFNT {
    struct Variations {
        struct Segment: Hashable {
            let from: Float
            let to: Float
        }

        let axes: [VariationAxis]
        let instances: [NamedVariationInstance]
        let mappings: [[Segment]]

        static func parse(
            fvar: Table?,
            avar: Table?,
            bytes: [UInt8]
        ) throws -> Self? {
            guard let fvar else { return nil }
            let reader = ByteReader(bytes)
            try reader.require(fvar.offset, count: 16)
            guard try reader.uint16(at: fvar.offset) == 1 else {
                throw RegistrationError.malformedRequiredTable
            }
            let axesOffset = Int(try reader.uint16(at: fvar.offset + 4))
            let axisCount = Int(try reader.uint16(at: fvar.offset + 8))
            let axisSize = Int(try reader.uint16(at: fvar.offset + 10))
            let instanceCount = Int(try reader.uint16(at: fvar.offset + 12))
            let instanceSize = Int(try reader.uint16(at: fvar.offset + 14))
            guard axisCount > 0, axisSize >= 20,
                  instanceSize >= 4 + axisCount * 4,
                  axesOffset >= 0,
                  axesOffset <= fvar.length,
                  axisCount <= (fvar.length - axesOffset) / axisSize
            else { throw RegistrationError.malformedRequiredTable }

            var axes: [VariationAxis] = []
            axes.reserveCapacity(axisCount)
            for index in 0..<axisCount {
                let offset = fvar.offset + axesOffset + index * axisSize
                let minimum = try reader.fixed16_16(at: offset + 4)
                let defaultValue = try reader.fixed16_16(at: offset + 8)
                let maximum = try reader.fixed16_16(at: offset + 12)
                guard minimum <= defaultValue, defaultValue <= maximum else {
                    throw RegistrationError.malformedRequiredTable
                }
                axes.append(.init(
                    tag: try reader.uint32(at: offset),
                    minimum: minimum,
                    defaultValue: defaultValue,
                    maximum: maximum,
                    flags: try reader.uint16(at: offset + 16),
                    nameID: try reader.uint16(at: offset + 18)
                ))
            }

            let instancesOffset = axesOffset + axisCount * axisSize
            guard instanceCount <= (fvar.length - instancesOffset) / instanceSize else {
                throw RegistrationError.malformedRequiredTable
            }
            var instances: [NamedVariationInstance] = []
            instances.reserveCapacity(instanceCount)
            for index in 0..<instanceCount {
                let offset = fvar.offset + instancesOffset + index * instanceSize
                var coordinates: [Float] = []
                coordinates.reserveCapacity(axisCount)
                for axis in 0..<axisCount {
                    coordinates.append(try reader.fixed16_16(at: offset + 4 + axis * 4))
                }
                let nameOffset = 4 + axisCount * 4
                let postScriptNameID = instanceSize >= nameOffset + 2
                    ? try reader.uint16(at: offset + nameOffset)
                    : nil
                instances.append(.init(
                    nameID: try reader.uint16(at: offset),
                    postScriptNameID: postScriptNameID == 0xFFFF ? nil : postScriptNameID,
                    coordinates: coordinates
                ))
            }

            return .init(
                axes: axes,
                instances: instances,
                mappings: try parseMappings(avar, axisCount: axisCount, reader: reader)
            )
        }

        func normalizedCoordinates(settings: [(UInt32, Float)]) -> [Float] {
            var result: [Float] = []
            result.reserveCapacity(axes.count)
            for index in axes.indices {
                let axis = axes[index]
                let requested = settings.first(where: { $0.0 == axis.tag })?.1
                    ?? axis.defaultValue
                let value = min(axis.maximum, max(axis.minimum, requested))
                let normalized: Float
                if value == axis.defaultValue {
                    normalized = 0
                } else if value < axis.defaultValue {
                    let denominator = axis.defaultValue - axis.minimum
                    normalized = denominator == 0 ? -1 : (value - axis.defaultValue) / denominator
                } else {
                    let denominator = axis.maximum - axis.defaultValue
                    normalized = denominator == 0 ? 1 : (value - axis.defaultValue) / denominator
                }
                result.append(remap(normalized, through: mappings[index]))
            }
            return result
        }

        private func remap(_ value: Float, through segments: [Segment]) -> Float {
            guard !segments.isEmpty else { return value }
            if value <= segments[0].from { return segments[0].to }
            for index in 1..<segments.count where value <= segments[index].from {
                let lower = segments[index - 1]
                let upper = segments[index]
                let distance = upper.from - lower.from
                guard distance != 0 else { return upper.to }
                let amount = (value - lower.from) / distance
                return lower.to + (upper.to - lower.to) * amount
            }
            return segments[segments.count - 1].to
        }

        private static func parseMappings(
            _ table: Table?,
            axisCount: Int,
            reader: ByteReader
        ) throws -> [[Segment]] {
            guard let table else {
                return Array(repeating: [], count: axisCount)
            }
            try reader.require(table.offset, count: 8)
            guard try reader.uint16(at: table.offset) == 1,
                  Int(try reader.uint16(at: table.offset + 6)) == axisCount
            else { throw RegistrationError.malformedRequiredTable }
            var offset = table.offset + 8
            var mappings: [[Segment]] = []
            mappings.reserveCapacity(axisCount)
            for _ in 0..<axisCount {
                let count = Int(try reader.uint16(at: offset))
                offset += 2
                try reader.require(offset, count: count * 4)
                var segments: [Segment] = []
                segments.reserveCapacity(count)
                var previous = -Float.greatestFiniteMagnitude
                for _ in 0..<count {
                    let from = try reader.f2dot14(at: offset)
                    let to = try reader.f2dot14(at: offset + 2)
                    guard from >= previous else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    segments.append(.init(from: from, to: to))
                    previous = from
                    offset += 4
                }
                mappings.append(segments)
            }
            guard offset <= table.offset + table.length else {
                throw RegistrationError.malformedRequiredTable
            }
            return mappings
        }
    }
}
