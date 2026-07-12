import Darwin
import Foundation
import PixlPlatform

extension ExecutionTopology {
    static var `default`: ExecutionTopology {
        let availableCount = max(
            1,
            ProcessInfo.processInfo.activeProcessorCount
        )
        let performanceCount = sysctlInteger(
            named: "hw.perflevel0.logicalcpu"
        ).flatMap { count in
            (1...availableCount).contains(count) ? count : nil
        }

        return ExecutionTopology(
            availableProcessorCount: availableCount,
            performanceProcessorCount: performanceCount
        )
    }

    private static func sysctlInteger(named name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let status = sysctlbyname(name, &value, &size, nil, 0)
        guard status == 0, value > 0 else { return nil }
        return Int(value)
    }
}
