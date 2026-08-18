import Foundation
import Metal
import PixlRenderer
import Swift

@main
struct MetalSharedBufferBenchmarks {
    private enum GPURead: Equatable {
        case completed
        case overlapping
    }

    private static let particleCount = 1_000_000
    private static let warmupCount = 10
    private static let sampleCount = 51

    static func main() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue()
        else { preconditionFailure("Metal is unavailable") }

        try benchmark(device: device, queue: queue, gpuRead: .completed)
        try benchmark(device: device, queue: queue, gpuRead: .overlapping)
        try benchmarkWallClockCadence(device: device, queue: queue)
    }

    @_optimize(none)
    private static func benchmarkWallClockCadence(
        device: any MTLDevice,
        queue: any MTLCommandQueue
    ) throws {
        let system = System(
            seed: 0x0123456789ABCDEF,
            particleCount: particleCount,
            spawnRegion: .point(.zero),
            duration: .seconds(60)
        )
        let buffers = try system.withRenderingData { buffers, _ in
            try SharedPositions(device: device, buffers: buffers)
        }
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        _ = system.diagnosticSample(at: .now)

        while samples.count < warmupCount + sampleCount {
            let firstFrame = try buffers.read(using: queue)
            Thread.sleep(forTimeInterval: 1.0 / 60.0)
            let secondFrame = try buffers.read(using: queue)
            Thread.sleep(forTimeInterval: 1.0 / 60.0)

            if let duration = system.diagnosticSample(
                at: .now
            ).fixedUpdateTime {
                samples.append(duration)
            }
            firstFrame.waitUntilCompleted()
            secondFrame.waitUntilCompleted()
        }

        samples.removeFirst(warmupCount)
        let average = samples.reduce(0, +) / Double(samples.count) * 1_000
        samples.sort()

        let median = samples[sampleCount / 2] * 1_000
        let p95 = samples[Int(Double(sampleCount - 1) * 0.95)] * 1_000
        print(
            "Real 30 Hz cadence with 60 Hz GPU reads: average \(average), "
                + "median \(median), p95 \(p95) ms/tick"
        )
    }

    @_optimize(none)
    private static func benchmark(
        device: any MTLDevice,
        queue: any MTLCommandQueue,
        gpuRead: GPURead
    ) throws {
        let system = System(
            seed: 0x0123456789ABCDEF,
            particleCount: particleCount,
            spawnRegion: .point(.zero),
            duration: .seconds(60)
        )
        let buffers = try system.withRenderingData { buffers, _ in
            try SharedPositions(device: device, buffers: buffers)
        }
        var instant = ContinuousClock.now
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        _ = system.diagnosticSample(at: instant)

        while samples.count < warmupCount + sampleCount {
            let commandBuffer = try buffers.read(using: queue)
            if gpuRead == .completed {
                commandBuffer.waitUntilCompleted()
            }

            instant = instant.advanced(by: .seconds(1.0 / 30.0))
            if let duration = system.diagnosticSample(
                at: instant
            ).fixedUpdateTime {
                samples.append(duration)
            }
            commandBuffer.waitUntilCompleted()
        }

        samples.removeFirst(warmupCount)
        let average = samples.reduce(0, +) / Double(samples.count) * 1_000
        samples.sort()

        let median = samples[sampleCount / 2] * 1_000
        let p95 = samples[Int(Double(sampleCount - 1) * 0.95)] * 1_000
        let name = gpuRead == .completed
            ? "Completed GPU read"
            : "Overlapping GPU read"
        print(
            "\(name): average \(average), median \(median), p95 \(p95) "
                + "ms/tick"
        )
    }
}

private struct SharedPositions {
    let previous: any MTLBuffer
    let current: any MTLBuffer
    let previousCopy: any MTLBuffer
    let currentCopy: any MTLBuffer
    let byteCount: Int

    init(device: any MTLDevice, buffers: ParticleBuffers) throws {
        previous = try Self.makeShared(device: device, host: buffers.previousPositions)
        current = try Self.makeShared(device: device, host: buffers.currentPositions)
        byteCount = buffers.currentPositions.byteCount

        guard let previousCopy = device.makeBuffer(
            length: byteCount,
            options: .storageModePrivate
        ), let currentCopy = device.makeBuffer(
            length: byteCount,
            options: .storageModePrivate
        ) else { throw BenchmarkError.buffer }

        self.previousCopy = previousCopy
        self.currentCopy = currentCopy
    }

    func read(
        using queue: any MTLCommandQueue
    ) throws -> any MTLCommandBuffer {
        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeBlitCommandEncoder()
        else { throw BenchmarkError.command }

        encoder.copy(
            from: previous,
            sourceOffset: 0,
            to: previousCopy,
            destinationOffset: 0,
            size: byteCount
        )
        encoder.copy(
            from: current,
            sourceOffset: 0,
            to: currentCopy,
            destinationOffset: 0,
            size: byteCount
        )
        encoder.endEncoding()
        commandBuffer.commit()
        return commandBuffer
    }

    private static func makeShared(
        device: any MTLDevice,
        host: HostBuffer
    ) throws -> any MTLBuffer {
        try host.withUnsafeMutableAllocatedBytes { bytes in
            guard let address = bytes.baseAddress,
                  let buffer = device.makeBuffer(
                    bytesNoCopy: address,
                    length: bytes.count,
                    options: .storageModeShared,
                    deallocator: nil
                  )
            else { throw BenchmarkError.buffer }
            return buffer
        }
    }
}

private enum BenchmarkError: Error {
    case buffer
    case command
}
