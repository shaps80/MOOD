import Foundation
import Metal

/// Bounded leases: never reuse a sample buffer until its completion callback
/// has resolved it. Counter availability must never stall rendering.
final class GPUTimingPool: @unchecked Sendable {
    private let device: any MTLDevice
    private let counterSet: (any MTLCounterSet)?
    private let lock = NSLock()
    private var available: [GPUTimingSample] = []
    private var allocated = 0

    init(device: any MTLDevice) {
        self.device = device
        counterSet = device.supportsCounterSampling(.atStageBoundary)
            ? device.counterSets?.first { $0.name == MTLCommonCounterSet.timestamp.rawValue }
            : nil
    }

    func acquire() -> GPUTimingSample? {
        lock.lock()
        defer { lock.unlock() }
        guard let counterSet else { return nil }
        if let sample = available.popLast() {
            sample.begin()
            return sample
        }
        guard allocated < 4 else { return nil }
        let descriptor = MTLCounterSampleBufferDescriptor()
        descriptor.counterSet = counterSet
        descriptor.storageMode = .shared
        descriptor.sampleCount = GPUTimingSample.capacity
        descriptor.label = "Frame GPU Timestamps"
        guard let buffer = try? device.makeCounterSampleBuffer(descriptor: descriptor)
        else { return nil }
        let sample = GPUTimingSample(device: device, buffer: buffer)
        allocated += 1
        sample.begin()
        return sample
    }

    func release(_ sample: GPUTimingSample) {
        lock.lock()
        available.append(sample)
        lock.unlock()
    }
}
