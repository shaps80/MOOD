extension SFNT {
    struct OpenTypeFeatureVariations {
        struct Condition: Hashable {
            let axisIndex: Int
            let minimum: Float
            let maximum: Float
        }

        struct Substitution: Hashable {
            let featureIndex: Int
            let lookupIndices: [Int]
        }

        struct Record: Hashable {
            let conditions: [Condition]
            let substitutions: [Substitution]
        }

        let records: [Record]

        static func parse(
            at offset: Int,
            table: Table,
            featureCount: Int,
            reader: ByteReader
        ) throws -> Self {
            try require(table, at: offset, count: 8)
            guard try reader.uint16(at: offset) == 1,
                  try reader.uint16(at: offset + 2) == 0
            else { throw RegistrationError.malformedRequiredTable }
            let count = Int(try reader.uint32(at: offset + 4))
            try require(table, at: offset + 8, count: try byteCount(count, 8))
            var records: [Record] = []
            records.reserveCapacity(count)
            for index in 0..<count {
                let record = offset + 8 + index * 8
                let conditionSet = offset + Int(try reader.uint32(at: record))
                let substitution = offset + Int(try reader.uint32(at: record + 4))
                records.append(.init(
                    conditions: try parseConditions(
                        at: conditionSet,
                        table: table,
                        reader: reader
                    ),
                    substitutions: try parseSubstitutions(
                        at: substitution,
                        table: table,
                        featureCount: featureCount,
                        reader: reader
                    )
                ))
            }
            return .init(records: records)
        }

        func substitutions(coordinates: [Float]) -> [Substitution] {
            for record in records where record.conditions.allSatisfy({ condition in
                coordinates.indices.contains(condition.axisIndex)
                    && coordinates[condition.axisIndex] >= condition.minimum
                    && coordinates[condition.axisIndex] <= condition.maximum
            }) {
                return record.substitutions
            }
            return []
        }

        func validate(lookupCount: Int) throws {
            for record in records {
                for substitution in record.substitutions {
                    guard substitution.lookupIndices.allSatisfy({
                        $0 >= 0 && $0 < lookupCount
                    }) else { throw RegistrationError.malformedRequiredTable }
                }
            }
        }

        private static func parseConditions(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Condition] {
            try require(table, at: offset, count: 2)
            let count = Int(try reader.uint16(at: offset))
            try require(table, at: offset + 2, count: try byteCount(count, 4))
            var result: [Condition] = []
            result.reserveCapacity(count)
            for index in 0..<count {
                let condition = offset + Int(try reader.uint32(at: offset + 2 + index * 4))
                try require(table, at: condition, count: 8)
                guard try reader.uint16(at: condition) == 1 else {
                    throw RegistrationError.malformedRequiredTable
                }
                let minimum = try reader.f2dot14(at: condition + 4)
                let maximum = try reader.f2dot14(at: condition + 6)
                guard minimum <= maximum else { throw RegistrationError.malformedRequiredTable }
                result.append(.init(
                    axisIndex: Int(try reader.uint16(at: condition + 2)),
                    minimum: minimum,
                    maximum: maximum
                ))
            }
            return result
        }

        private static func parseSubstitutions(
            at offset: Int,
            table: Table,
            featureCount: Int,
            reader: ByteReader
        ) throws -> [Substitution] {
            try require(table, at: offset, count: 6)
            guard try reader.uint16(at: offset) == 1,
                  try reader.uint16(at: offset + 2) == 0
            else { throw RegistrationError.malformedRequiredTable }
            let count = Int(try reader.uint16(at: offset + 4))
            try require(table, at: offset + 6, count: try byteCount(count, 6))
            var result: [Substitution] = []
            result.reserveCapacity(count)
            for index in 0..<count {
                let record = offset + 6 + index * 6
                let featureIndex = Int(try reader.uint16(at: record))
                guard featureIndex < featureCount else {
                    throw RegistrationError.malformedRequiredTable
                }
                let alternate = offset + Int(try reader.uint32(at: record + 2))
                try require(table, at: alternate, count: 4)
                let lookupCount = Int(try reader.uint16(at: alternate + 2))
                try require(table, at: alternate + 4, count: try byteCount(lookupCount, 2))
                var lookupIndices: [Int] = []
                lookupIndices.reserveCapacity(lookupCount)
                for lookup in 0..<lookupCount {
                    lookupIndices.append(Int(try reader.uint16(at: alternate + 4 + lookup * 2)))
                }
                result.append(.init(featureIndex: featureIndex, lookupIndices: lookupIndices))
            }
            return result
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
