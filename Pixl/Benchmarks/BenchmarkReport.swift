import Swift

struct BenchmarkReport: CustomStringConvertible {
    struct Measurement {
        let name: String
        let statistics: BenchmarkStatistics
    }

    let warmupFrameCount: Int
    let measuredFrameCount: Int
    let submissionCount: Int
    let visibleCount: Int
    let colliderCount: Int
    let collisionReportCount: Int
    let queryHitCount: Int
    let rayHitCount: Int
    let checksum: UInt64
    let memory: MemoryReport
    let measurements: [Measurement]

    var description: String {
        var lines = [
            "Pixl representative CPU frame",
            "Workload: \(submissionCount) submissions, \(visibleCount) visible, "
                + "\(colliderCount) colliders",
            "Samples: \(measuredFrameCount) frames after \(warmupFrameCount) warm-ups",
            "Correctness: \(collisionReportCount) collision reports, "
                + "\(queryHitCount) query hits, \(rayHitCount) ray hits "
                + "[\(checksum)]",
        ]
        for measurement in measurements {
            let value = measurement.statistics
            lines.append(
                "\(measurement.name): median \(milliseconds(value.median)) ms, "
                    + "p95 \(milliseconds(value.p95)) ms, "
                    + "max \(milliseconds(value.maximum)) ms"
            )
        }
        lines.append(contentsOf: memory.descriptionLines)
        return lines.joined(separator: "\n")
    }

    var json: String {
        let values = measurements.map { measurement in
            let value = measurement.statistics
            return "{\"name\":\"\(measurement.name)\","
                + "\"medianSeconds\":\(value.median),"
                + "\"p95Seconds\":\(value.p95),"
                + "\"maximumSeconds\":\(value.maximum)}"
        }.joined(separator: ",")
        return "{\"benchmark\":\"Pixl representative CPU frame\","
            + "\"warmupFrames\":\(warmupFrameCount),"
            + "\"measuredFrames\":\(measuredFrameCount),"
            + "\"submissionCount\":\(submissionCount),"
            + "\"visibleCount\":\(visibleCount),"
            + "\"colliderCount\":\(colliderCount),"
            + "\"collisionReportCount\":\(collisionReportCount),"
            + "\"queryHitCount\":\(queryHitCount),"
            + "\"rayHitCount\":\(rayHitCount),"
            + "\"checksum\":\"\(checksum)\","
            + "\"residentBytesBefore\":\(json(memory.before)),"
            + "\"residentBytesAfterWorkload\":\(json(memory.afterWorkload)),"
            + "\"residentBytesAfterWarmup\":\(json(memory.afterWarmup)),"
            + "\"residentBytesAfterMeasurement\":\(json(memory.afterMeasurement)),"
            + "\"peakResidentBytes\":\(json(memory.peak)),"
            + "\"measurements\":[\(values)]}"
    }

    private func milliseconds(_ seconds: Double) -> String {
        BenchmarkFormatting.decimal(seconds * 1_000, places: 3)
    }

    private func json(_ value: UInt64?) -> String {
        value.map(String.init) ?? "null"
    }
}
