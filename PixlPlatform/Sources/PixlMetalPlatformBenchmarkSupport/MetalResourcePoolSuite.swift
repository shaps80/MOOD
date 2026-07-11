import Metal
import PixlPlatform
import PixlPlatformTestSupport

package struct MetalResourcePoolRuntimeReport {
    package let poolOnlySequentialResolution: BenchmarkResult
    package let directSequentialAttachmentBinding: BenchmarkResult
    package let sequentialResolution: BenchmarkResult
    package let poolOnlyRandomResolution: BenchmarkResult
    package let directRandomAttachmentBinding: BenchmarkResult
    package let randomResolution: BenchmarkResult
    package let drawableChurn: BenchmarkResult
    package let textureReplacement: BenchmarkResult

    package func printResults() {
        let capacity = RenderSettings.default.textureCapacity
        print("Metal ResourcePool runtime scenario — \(capacity) distinct MTLTextures")
        print("Configuration: release")
        print("Storage: ResourcePool<MTLTexture>; capacity from RenderSettings.default")
        print("Resolution: same attachment assignment shape as MetalQueue.encode")
        print("")

        printResult(poolOnlySequentialResolution)
        printResult(directSequentialAttachmentBinding)
        printResult(sequentialResolution)
        printResult(poolOnlyRandomResolution)
        printResult(directRandomAttachmentBinding)
        printResult(randomResolution)
        printResult(drawableChurn)
        printResult(textureReplacement)

        let checksum = poolOnlySequentialResolution.checksum
            &+ directSequentialAttachmentBinding.checksum
            &+ sequentialResolution.checksum
            &+ poolOnlyRandomResolution.checksum
            &+ directRandomAttachmentBinding.checksum
            &+ randomResolution.checksum
            &+ drawableChurn.checksum
            &+ textureReplacement.checksum
        print("Checksum: \(checksum)")
    }

    private func printResult(_ result: BenchmarkResult) {
        print(result.name)
        print("  Average: \(milliseconds(result.averageNanoseconds)) ms")
        print("  Per operation: \(decimalHundredths(result.nanosecondsPerOperationHundredths)) ns")
        print("  Min: \(milliseconds(result.minimumNanoseconds)) ms")
        print("  Max: \(milliseconds(result.maximumNanoseconds)) ms")
        print("  Iterations: \(result.iterations)")
    }

    private func milliseconds(_ nanoseconds: UInt64) -> String {
        decimalThousandths(nanoseconds / 1_000)
    }

    private func decimalThousandths(_ thousandths: UInt64) -> String {
        "\(thousandths / 1_000).\(leftPadded(thousandths % 1_000, width: 3))"
    }

    private func decimalHundredths(_ hundredths: UInt64) -> String {
        "\(hundredths / 100).\(leftPadded(hundredths % 100, width: 2))"
    }

    private func leftPadded(_ value: UInt64, width: Int) -> String {
        let value = String(value)
        return String(repeating: "0", count: max(0, width - value.count)) + value
    }
}

package enum MetalResourcePoolRuntimeScenario {
    private static let framesPerResolutionIteration = 2_048
    private static let framesPerMutationIteration = 100_000

    package static func runChecks() throws {
        let fixture = try Fixture(capacity: RenderSettings.default.textureCapacity)

        guard fixture.pool.count == fixture.capacity,
              fixture.pool.withValue(for: fixture.ids[0], { $0.pointee.width }) == 1,
              fixture.replaceOne(),
              fixture.bindSequential(frames: 1) != 0,
              fixture.bindRandom(frames: 1) != 0
        else {
            throw MetalResourcePoolError.checkFailed
        }

        let drawableFixture = try DrawableFixture(capacity: fixture.capacity)
        guard drawableFixture.churn(frames: 1) != 0 else {
            throw MetalResourcePoolError.checkFailed
        }
    }

    package static func runBenchmarks() -> MetalResourcePoolRuntimeReport {
        let fixture: Fixture
        let drawableFixture: DrawableFixture

        do {
            fixture = try Fixture(capacity: RenderSettings.default.textureCapacity)
            drawableFixture = try DrawableFixture(capacity: RenderSettings.default.textureCapacity)
        } catch {
            fatalError("Metal texture setup failed: \(error)")
        }

        let resolutionOperations = UInt64(fixture.capacity) * UInt64(framesPerResolutionIteration)
        let mutationOperations = UInt64(framesPerMutationIteration)

        let poolOnlySequentialResolution = Benchmark.measure(
            name: "Pool-only sequential resolution",
            operationsPerIteration: resolutionOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.resolveSequential(frames: framesPerResolutionIteration)
        }

        let directSequentialAttachmentBinding = Benchmark.measure(
            name: "Direct sequential attachment binding",
            operationsPerIteration: resolutionOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.bindDirectSequential(frames: framesPerResolutionIteration)
        }

        let sequentialResolution = Benchmark.measure(
            name: "Sequential texture resolution",
            operationsPerIteration: resolutionOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.bindSequential(frames: framesPerResolutionIteration)
        }

        fixture.shuffleIDs()
        let poolOnlyRandomResolution = Benchmark.measure(
            name: "Pool-only random resolution",
            operationsPerIteration: resolutionOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.resolveRandom(frames: framesPerResolutionIteration)
        }

        let directRandomAttachmentBinding = Benchmark.measure(
            name: "Direct random attachment binding",
            operationsPerIteration: resolutionOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.bindDirectRandom(frames: framesPerResolutionIteration)
        }

        let randomResolution = Benchmark.measure(
            name: "Random-order texture resolution",
            operationsPerIteration: resolutionOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.bindRandom(frames: framesPerResolutionIteration)
        }

        let drawableChurn = Benchmark.measure(
            name: "Transient drawable churn",
            operationsPerIteration: mutationOperations * 2,
            warmupIterations: 5,
            iterations: 50
        ) {
            drawableFixture.churn(frames: framesPerMutationIteration)
        }

        let textureReplacement = Benchmark.measure(
            name: "Single texture replacement",
            operationsPerIteration: mutationOperations,
            warmupIterations: 5,
            iterations: 50
        ) {
            fixture.replace(frames: framesPerMutationIteration)
        }

        return MetalResourcePoolRuntimeReport(
            poolOnlySequentialResolution: poolOnlySequentialResolution,
            directSequentialAttachmentBinding: directSequentialAttachmentBinding,
            sequentialResolution: sequentialResolution,
            poolOnlyRandomResolution: poolOnlyRandomResolution,
            directRandomAttachmentBinding: directRandomAttachmentBinding,
            randomResolution: randomResolution,
            drawableChurn: drawableChurn,
            textureReplacement: textureReplacement
        )
    }
}

private final class Fixture {
    let pool: ResourcePool<MTLTexture>
    let ids: UnsafeMutablePointer<ResourceID>
    let capacity: UInt32

    private let textures: UnsafeMutablePointer<MTLTexture>
    private let replacementA: MTLTexture
    private let replacementB: MTLTexture
    private let descriptor = MTLRenderPassDescriptor()
    private var replacement: MTLTexture
    private var replacementIndex: UInt32 = 0

    init(capacity: UInt32) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalResourcePoolError.metalUnavailable
        }

        self.capacity = capacity
        pool = ResourcePool(capacity: capacity)
        ids = .allocate(capacity: Int(capacity))
        textures = .allocate(capacity: Int(capacity))
        replacementA = try Self.makeTexture(device: device)
        replacementB = try Self.makeTexture(device: device)
        replacement = replacementA

        for index in 0..<capacity {
            let texture = try Self.makeTexture(device: device)
            textures.advanced(by: Int(index)).initialize(to: texture)
            ids.advanced(by: Int(index)).initialize(to: pool.insert(texture)!)
        }
    }

    deinit {
        ids.deinitialize(count: Int(capacity))
        ids.deallocate()
        textures.deinitialize(count: Int(capacity))
        textures.deallocate()
    }

    func bindSequential(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            for index in 0..<capacity {
                let id = ids[Int(index)]
                precondition(pool.withValue(for: id) {
                    descriptor.colorAttachments[0].texture = $0.pointee
                } != nil)
                checksum &+= id.rawValue
            }
        }

        return checksum
    }

    func resolveSequential(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            for index in 0..<capacity {
                let id = ids[Int(index)]
                precondition(pool.withValue(for: id) {
                    checksum &+= UInt64(UInt(bitPattern: $0))
                } != nil)
            }
        }

        return checksum
    }

    func bindDirectSequential(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            for index in 0..<capacity {
                descriptor.colorAttachments[0].texture = textures[Int(index)]
                checksum &+= UInt64(index)
            }
        }

        return checksum
    }

    func bindRandom(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            for index in 0..<capacity {
                let id = ids[Int(index)]
                precondition(pool.withValue(for: id) {
                    descriptor.colorAttachments[0].texture = $0.pointee
                } != nil)
                checksum &+= id.rawValue
            }
        }

        return checksum
    }

    func resolveRandom(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            for index in 0..<capacity {
                let id = ids[Int(index)]
                precondition(pool.withValue(for: id) {
                    checksum &+= UInt64(UInt(bitPattern: $0))
                } != nil)
            }
        }

        return checksum
    }

    func bindDirectRandom(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            for index in 0..<capacity {
                let id = ids[Int(index)]
                descriptor.colorAttachments[0].texture = textures[Int(id.index)]
                checksum &+= id.rawValue
            }
        }

        return checksum
    }

    @discardableResult
    func replaceOne() -> Bool {
        let id = ids[Int(replacementIndex)]
        replacementIndex = replacementIndex &+ 1 == capacity ? 0 : replacementIndex &+ 1
        replacement = replacement === replacementA ? replacementB : replacementA
        let next = replacement

        return pool.update(id) { $0.pointee = next } != nil
    }

    func replace(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            precondition(replaceOne())
            checksum &+= ids[Int(replacementIndex)].rawValue
        }

        return checksum
    }

    func shuffleIDs() {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15

        for index in stride(from: Int(capacity) - 1, through: 1, by: -1) {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27

            let other = Int(state % UInt64(index + 1))
            let value = ids[index]
            ids[index] = ids[other]
            ids[other] = value
        }
    }

    fileprivate static func makeTexture(device: MTLDevice) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalResourcePoolError.textureCreationFailed
        }

        return texture
    }
}

private final class DrawableFixture {
    private let pool: ResourcePool<MTLTexture>
    private let transient: MTLTexture

    init(capacity: UInt32) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalResourcePoolError.metalUnavailable
        }

        pool = ResourcePool(capacity: capacity)
        transient = try Fixture.makeTexture(device: device)

        for _ in 1..<capacity {
            guard let texture = try? Fixture.makeTexture(device: device), pool.insert(texture) != nil else {
                throw MetalResourcePoolError.textureCreationFailed
            }
        }
    }

    func churn(frames: Int) -> UInt64 {
        var checksum: UInt64 = 0

        for _ in 0..<frames {
            guard let id = pool.insert(transient) else {
                fatalError("Drawable fixture pool unexpectedly full")
            }
            checksum &+= id.rawValue
            precondition(pool.remove(id))
        }

        return checksum
    }
}

private enum MetalResourcePoolError: Error {
    case metalUnavailable
    case textureCreationFailed
    case checkFailed
}
