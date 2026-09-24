import Darwin
import Foundation

nonisolated struct SimulationWorkers {
    enum Mode: String {
        case serial
        case all
        // Sizes the pool to P-core count; macOS still owns thread placement.
        case performance
    }

    let mode: Mode
    let count: Int
    let batchesPerWorker: Int

    init(mode: Mode = .all, batchesPerWorker: Int = 4) {
        precondition(batchesPerWorker > 0 && batchesPerWorker <= 1024)
        self.mode = mode
        self.batchesPerWorker = batchesPerWorker
        switch mode {
        case .serial: count = 1
        case .all: count = Self.cpuCount("hw.physicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount
        case .performance:
            count = Self.cpuCount("hw.perflevel0.physicalcpu")
                ?? Self.cpuCount("hw.physicalcpu") ?? ProcessInfo.processInfo.activeProcessorCount
        }
    }

    static var environment: Self {
        let values = ProcessInfo.processInfo.environment
        return Self(mode: values["PIXL_SIMULATION_CORES"].flatMap(Mode.init(rawValue:)) ?? .all,
                    batchesPerWorker: values["PIXL_SIMULATION_BATCHES"].flatMap(Int.init) ?? 4)
    }

    private static func cpuCount(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, value > 0 else { return nil }
        return Int(value)
    }
}
