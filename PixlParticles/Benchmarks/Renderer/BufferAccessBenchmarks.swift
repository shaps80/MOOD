import Swift

@main
struct BufferAccessBenchmarks {
    private static let particleCount = 1_000_000
    private static let batchCount = particleCount / 4
    private static let iterationCount = 100
    private static let warmupCount = 10
    private static let sampleCount = 5
    private static let interpolation: Float = 0.25

    static func main() {
        let previous = UnsafeMutableBufferPointer<Vector3Batch>.allocate(
            capacity: batchCount
        )
        let current = UnsafeMutableBufferPointer<Vector3Batch>.allocate(
            capacity: batchCount
        )
        let destination = UnsafeMutableBufferPointer<Position>.allocate(
            capacity: particleCount
        )

        for index in 0..<batchCount {
            let base = Float(index * 4)
            let offsets: SIMD4<Float> = [0, 1, 2, 3]
            previous.initializeElement(
                at: index,
                to: batch(
                    x: .init(repeating: base) + offsets,
                    y: .init(repeating: base + 1) + offsets,
                    z: .init(repeating: base + 2) + offsets
                )
            )
            current.initializeElement(
                at: index,
                to: batch(
                    x: .init(repeating: base + 4) + offsets,
                    y: .init(repeating: base + 5) + offsets,
                    z: .init(repeating: base + 6) + offsets
                )
            )
        }
        destination.initialize(repeating: Position(x: 0, y: 0, z: 0))

        defer {
            previous.deinitialize()
            previous.deallocate()
            current.deinitialize()
            current.deallocate()
            destination.deinitialize()
            destination.deallocate()
        }

        let readPrevious = UnsafeBufferPointer(previous)
        let readCurrent = UnsafeBufferPointer(current)

        for _ in 0..<warmupCount {
            withSpans(readPrevious, readCurrent) { previous, current in
                lower(
                    previous: previous,
                    current: current,
                    into: destination
                )
            }
            lower(
                previous: readPrevious,
                current: readCurrent,
                into: destination
            )
        }

        benchmark(
            destination: UnsafeBufferPointer(destination),
            span: {
                withSpans(readPrevious, readCurrent) { previous, current in
                    lower(
                        previous: previous,
                        current: current,
                        into: destination
                    )
                }
            },
            unsafe: {
                lower(
                    previous: readPrevious,
                    current: readCurrent,
                    into: destination
                )
            }
        )
    }

    @_optimize(none)
    private static func benchmark(
        destination: UnsafeBufferPointer<Position>,
        span: () -> Void,
        unsafe: () -> Void
    ) {
        var spanSamples: [Double] = []
        var unsafeSamples: [Double] = []
        var result: UInt64 = 0

        spanSamples.reserveCapacity(sampleCount)
        unsafeSamples.reserveCapacity(sampleCount)

        for sample in 0..<sampleCount {
            if sample.isMultiple(of: 2) {
                spanSamples.append(measure(span))
                unsafeSamples.append(measure(unsafe))
            } else {
                unsafeSamples.append(measure(unsafe))
                spanSamples.append(measure(span))
            }
            result ^= checksum()
        }

        spanSamples.sort()
        unsafeSamples.sort()

        report("Span", elapsed: spanSamples[sampleCount / 2])
        report(
            "UnsafeBufferPointer",
            elapsed: unsafeSamples[sampleCount / 2]
        )

        @inline(never)
        func measure(_ body: () -> Void) -> Double {
            let clock = ContinuousClock()
            let start = clock.now
            for _ in 0..<iterationCount {
                body()
            }
            return seconds(start.duration(to: clock.now))
        }

        @inline(never)
        func report(_ name: String, elapsed: Double) {
            let valueCount = Double(particleCount * iterationCount)
            let throughput = valueCount / elapsed / 1_000_000
            let nanoseconds = elapsed / valueCount * 1_000_000_000

            print(
                "\(name): \(throughput) million particles/s, "
                    + "\(nanoseconds) ns/particle [\(result)]"
            )
        }

        @inline(never)
        func checksum() -> UInt64 {
            var result: UInt64 = 0
            let step = particleCount / 64
            var index = 0

            while index < particleCount {
                result &+= UInt64(destination[index].x.bitPattern)
                result &+= UInt64(destination[index].y.bitPattern)
                result &+= UInt64(destination[index].z.bitPattern)
                index += step
            }

            return result
        }
    }

    @inline(__always)
    private static func withSpans<Result: ~Copyable>(
        _ previous: UnsafeBufferPointer<Vector3Batch>,
        _ current: UnsafeBufferPointer<Vector3Batch>,
        _ body: (Span<Vector3Batch>, Span<Vector3Batch>) throws -> Result
    ) rethrows -> Result {
        try body(
            unsafe Span(_unsafeElements: previous),
            unsafe Span(_unsafeElements: current)
        )
    }

    @inline(never)
    private static func lower(
        previous: Span<Vector3Batch>,
        current: Span<Vector3Batch>,
        into destination: UnsafeMutableBufferPointer<Position>
    ) {
        for batchIndex in previous.indices {
            write(
                previous: previous[batchIndex],
                current: current[batchIndex],
                batchIndex: batchIndex,
                into: destination
            )
        }
    }

    @inline(never)
    private static func lower(
        previous: UnsafeBufferPointer<Vector3Batch>,
        current: UnsafeBufferPointer<Vector3Batch>,
        into destination: UnsafeMutableBufferPointer<Position>
    ) {
        for batchIndex in previous.indices {
            write(
                previous: previous[batchIndex],
                current: current[batchIndex],
                batchIndex: batchIndex,
                into: destination
            )
        }
    }

    @inline(__always)
    private static func write(
        previous: Vector3Batch,
        current: Vector3Batch,
        batchIndex: Int,
        into destination: UnsafeMutableBufferPointer<Position>
    ) {
        let x = previous.x + (current.x - previous.x) * interpolation
        let y = previous.y + (current.y - previous.y) * interpolation
        let z = previous.z + (current.z - previous.z) * interpolation
        let start = batchIndex * 4

        for lane in 0..<4 {
            destination[start + lane] = Position(
                x: x[lane],
                y: y[lane],
                z: z[lane]
            )
        }
    }

    @inline(__always)
    private static func batch(
        x: SIMD4<Float>,
        y: SIMD4<Float>,
        z: SIMD4<Float>
    ) -> Vector3Batch {
        var batch = Vector3Batch(repeating: .zero)
        batch.x = x
        batch.y = y
        batch.z = z
        return batch
    }

    @inline(__always)
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) * 1e-18
    }
}
