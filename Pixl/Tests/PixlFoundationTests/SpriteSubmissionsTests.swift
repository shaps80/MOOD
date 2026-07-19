import PixlFoundation
import PixlPlatform
import Testing

@Suite("Sprite submissions")
struct SpriteSubmissionsTests {
    @Test
    func capacityIsFixedAndOverflowDoesNotMutateStorage() {
        let storage = SpriteSubmissions(capacity: 2)

        #expect(storage.append(submission(texture: 1), layer: 0))
        #expect(storage.append(submission(texture: 2), layer: 1))
        #expect(!storage.append(submission(texture: 3), layer: 2))
        #expect(storage.count == 2)

        storage.consume { order, submissions in
            #expect(order.map(\.ordinal) == [0, 1])
            #expect(submissions.map(\.texture.rawValue) == [1, 2])
        }
    }

    @Test
    func consumeOrdersLayersAndPreservesEqualLayerSubmissionOrder() {
        let storage = SpriteSubmissions(capacity: 4)
        storage.append(submission(texture: 1), layer: 10)
        storage.append(submission(texture: 2), layer: 0)
        storage.append(submission(texture: 3), layer: 10)
        storage.append(submission(texture: 4), layer: 0)

        storage.consume { order, submissions in
            #expect(order.map(\.layer) == [0, 0, 10, 10])
            #expect(order.map(\.ordinal) == [1, 3, 0, 2])
            #expect(order.map { submissions[$0.ordinal].texture.rawValue } == [2, 4, 1, 3])
            #expect(submissions.map(\.texture.rawValue) == [1, 2, 3, 4])
        }
    }

    @Test
    func consumeResetsCountAndReusesTheSameAllocation() {
        let storage = SpriteSubmissions(capacity: 1)
        storage.append(submission(texture: 1), layer: 0)
        var firstAddress: UnsafeRawPointer?
        var firstOrderAddress: UnsafeRawPointer?

        storage.consume { order, submissions in
            firstAddress = submissions.baseAddress.map(UnsafeRawPointer.init)
            firstOrderAddress = order.baseAddress.map(UnsafeRawPointer.init)
        }

        #expect(storage.count == 0)
        #expect(storage.append(submission(texture: 2), layer: 0))

        storage.consume { order, submissions in
            #expect(
                submissions.baseAddress.map(UnsafeRawPointer.init)
                    == firstAddress
            )
            #expect(
                order.baseAddress.map(UnsafeRawPointer.init)
                    == firstOrderAddress
            )
            #expect(submissions[0].texture.rawValue == 2)
        }
    }

    @Test
    func snapshotsOwnEverySubmittedValue() {
        let storage = SpriteSubmissions(capacity: 1)
        let expected = submission(texture: 42)
        storage.append(expected, layer: 7)

        storage.consume { order, submissions in
            let snapshot = submissions[order[0].ordinal]

            #expect(order[0].layer == 7)
            #expect(snapshot.texture.rawValue == 42)
            #expect(snapshot.textureCoordinateOrigin == SIMD2(0.25, 0.5))
            #expect(snapshot.textureCoordinateScale == SIMD2(0.5, 0.25))
            #expect(snapshot.transformX == SIMD3(1, 2, 3))
            #expect(snapshot.transformY == SIMD3(4, 5, 6))
            #expect(snapshot.transformTranslation == SIMD3(7, 8, 9))
            #expect(snapshot.sampler.minFilter == .linear)
            #expect(snapshot.sampler.magFilter == .nearest)
            #expect(snapshot.sampler.addressModeU == .repeat)
            #expect(snapshot.sampler.addressModeV == .mirrorRepeat)
            #expect(snapshot.blendMode == .replace)
        }
    }

    private func submission(
        texture: UInt64
    ) -> SpriteSubmission {
        SpriteSubmission(
            texture: TextureResourceID(rawValue: texture),
            textureCoordinateOrigin: SIMD2(0.25, 0.5),
            textureCoordinateScale: SIMD2(0.5, 0.25),
            transformX: SIMD3(1, 2, 3),
            transformY: SIMD3(4, 5, 6),
            transformTranslation: SIMD3(7, 8, 9),
            sampler: SamplerDescriptor(
                minFilter: .linear,
                magFilter: .nearest,
                addressModeU: .repeat,
                addressModeV: .mirrorRepeat
            ),
            blendMode: .replace
        )
    }
}
