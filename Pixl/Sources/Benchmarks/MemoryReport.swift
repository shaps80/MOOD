import Swift

#if canImport(Darwin)
import Darwin
import MachO
#endif

struct MemoryReport {
    let before: UInt64?
    let afterWorkload: UInt64?
    let afterWarmup: UInt64?
    let afterMeasurement: UInt64?
    let peak: UInt64?

    var descriptionLines: [String] {
        guard let before,
              let afterWorkload,
              let afterWarmup,
              let afterMeasurement,
              let peak
        else {
            return ["Memory: unavailable on this platform"]
        }
        return [
            "Memory resident before: \(mebibytes(before)) MiB",
            "Memory resident after setup: \(mebibytes(afterWorkload)) MiB "
                + "(delta \(mebibytes(afterWorkload &- before)) MiB)",
            "Memory resident after warm-up: \(mebibytes(afterWarmup)) MiB "
                + "(delta \(signedMebibytes(afterWarmup, from: afterWorkload)) MiB)",
            "Memory resident after measurement: \(mebibytes(afterMeasurement)) MiB "
                + "(delta \(signedMebibytes(afterMeasurement, from: afterWarmup)) MiB)",
            "Memory peak resident: \(mebibytes(peak)) MiB",
        ]
    }

    static func residentBytes() -> UInt64? {
        #if canImport(Darwin)
        var information = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info_data_t>.size
                / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &information) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return UInt64(information.resident_size)
        #else
        return nil
        #endif
    }

    static func peakResidentBytes() -> UInt64? {
        #if canImport(Darwin)
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return nil }
        return UInt64(usage.ru_maxrss)
        #else
        return nil
        #endif
    }

    private func mebibytes(_ bytes: UInt64) -> String {
        BenchmarkFormatting.decimal(Double(bytes) / 1_048_576, places: 2)
    }

    private func signedMebibytes(_ bytes: UInt64, from previous: UInt64) -> String {
        let difference = Double(bytes) - Double(previous)
        return BenchmarkFormatting.decimal(difference / 1_048_576, places: 2)
    }
}
