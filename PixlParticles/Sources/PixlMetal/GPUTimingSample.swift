import Foundation
import Metal
import PixlRenderer

/// Encoding owns this sample until submission; completion then owns resolution.
final class GPUTimingSample: @unchecked Sendable {
    static let capacity = 128
    let buffer: any MTLCounterSampleBuffer
    private let device: any MTLDevice
    private var cpuStart: MTLTimestamp = 0
    private var gpuStart: MTLTimestamp = 0
    private var nextIndex = 0
    private var compute: [(GPUComputePhase, Int)] = []
    private var render: [Int] = []
    private var overflow = false

    init(device: any MTLDevice, buffer: any MTLCounterSampleBuffer) {
        self.device = device
        self.buffer = buffer
        compute.reserveCapacity(Self.capacity / 2)
        render.reserveCapacity(4)
    }

    func begin() {
        nextIndex = 0
        overflow = false
        compute.removeAll(keepingCapacity: true)
        render.removeAll(keepingCapacity: true)
        let start = device.sampleTimestamps()
        cpuStart = start.cpu
        gpuStart = start.gpu
    }

    func attach(to descriptor: MTLComputePassDescriptor, phase: GPUComputePhase) {
        guard nextIndex + 2 <= Self.capacity else { overflow = true; return }
        let attachment = descriptor.sampleBufferAttachments[0]!
        attachment.sampleBuffer = buffer
        attachment.startOfEncoderSampleIndex = nextIndex
        attachment.endOfEncoderSampleIndex = nextIndex + 1
        compute.append((phase, nextIndex))
        nextIndex += 2
    }

    func attach(to descriptor: MTLRenderPassDescriptor) {
        guard nextIndex + 4 <= Self.capacity else { overflow = true; return }
        let attachment = descriptor.sampleBufferAttachments[0]!
        attachment.sampleBuffer = buffer
        attachment.startOfVertexSampleIndex = nextIndex
        attachment.endOfVertexSampleIndex = nextIndex + 1
        attachment.startOfFragmentSampleIndex = nextIndex + 2
        attachment.endOfFragmentSampleIndex = nextIndex + 3
        render.append(nextIndex)
        nextIndex += 4
    }

    func resolve(total: Double?, trace: (@Sendable (GPUTraceInterval) -> Void)? = nil,
                 frameID: UInt64 = 0, captureID: UInt64 = 0) -> GPUFrameTimings {
        let end = device.sampleTimestamps()
        let cpuEnd = end.cpu
        let gpuEnd = end.gpu
        guard !overflow, nextIndex > 0, cpuEnd > cpuStart, gpuEnd > gpuStart,
              let data = try? buffer.resolveCounterRange(0..<nextIndex),
              data.count >= nextIndex * MemoryLayout<MTLCounterResultTimestamp>.stride
        else { return .init(total: total) }
        // sampleTimestamps CPU values are nanoseconds, per Metal's clock
        // conversion contract; do not apply mach_timebase_info a second time.
        let secondsPerTick = Double(cpuEnd - cpuStart) / Double(gpuEnd - gpuStart) / 1e9
        return data.withUnsafeBytes { bytes in
            func timestamp(_ index: Int) -> UInt64? {
                let value = bytes.loadUnaligned(
                    fromByteOffset: index * MemoryLayout<MTLCounterResultTimestamp>.stride,
                    as: MTLCounterResultTimestamp.self
                ).timestamp
                return value == 0 || value == MTLCounterErrorValue ? nil : value
            }
            func interval(_ start: Int, _ end: Int) -> Double? {
                guard let a = timestamp(start), let b = timestamp(end), b >= a else { return nil }
                return Double(b - a) * secondsPerTick
            }
            func emit(_ phase: GPUTraceInterval.Phase, _ start: Int, _ end: Int, computePhase: GPUComputePhase? = nil) {
                guard let trace, let a = timestamp(start), let b = timestamp(end), b >= a else { return }
                func hostSeconds(_ value: UInt64) -> Double {
                    let delta = value >= gpuStart ? Double(value - gpuStart) : -Double(gpuStart - value)
                    return Double(cpuStart) / 1e9 + delta * secondsPerTick
                }
                trace(.init(phase: phase, start: hostSeconds(a), end: hostSeconds(b),
                            frameID: frameID, captureID: captureID, computePhase: computePhase))
            }
            if trace != nil {
                for (phase, index) in compute {
                    emit(phase.isDiagnostics ? .diagnostics : .preparation, index, index + 1, computePhase: phase)
                }
                for index in render {
                    emit(.vertex, index, index + 1)
                    emit(.fragment, index + 2, index + 3)
                }
            }
            func sum(_ phase: GPUComputePhase) -> Double? {
                var result = 0.0
                for (kind, index) in compute where kind.isDiagnostics == phase.isDiagnostics {
                    guard let duration = interval(index, index + 1) else { return nil }
                    result += duration
                }
                return result
            }
            var draw = 0.0, vertex = 0.0, fragment = 0.0
            for index in render {
                guard let v = interval(index, index + 1),
                      let f = interval(index + 2, index + 3),
                      let vs = timestamp(index), let ve = timestamp(index + 1),
                      let fs = timestamp(index + 2), let fe = timestamp(index + 3)
                else { return .init(total: total, preparation: sum(.preparation), diagnostics: sum(.diagnostics)) }
                vertex += v
                fragment += f
                draw += Double(max(ve, fe) - min(vs, fs)) * secondsPerTick
            }
            return .init(total: total, preparation: sum(.preparation), diagnostics: sum(.diagnostics),
                         draw: render.isEmpty ? nil : draw,
                         vertex: render.isEmpty ? nil : vertex,
                         fragment: render.isEmpty ? nil : fragment)
        }
    }
}
