import Swift

/// An opaque handle to immutable texture-sampling state.
public struct Sampler: Hashable, Sendable {
    package let id: ResourceID
    /// Description used to create this sampler.
    public let descriptor: SamplerDescriptor

    package init(
        id: ResourceID,
        descriptor: SamplerDescriptor
    ) {
        self.id = id
        self.descriptor = descriptor
    }
}

/// Texture filtering and out-of-range addressing configuration.
public struct SamplerDescriptor: Hashable, Sendable {
    /// Filter used when shrinking a texture.
    public var minFilter: SamplerFilter
    /// Filter used when enlarging a texture.
    public var magFilter: SamplerFilter
    /// Filter used between mip levels.
    public var mipFilter: SamplerFilter
    /// Addressing along the u coordinate.
    public var addressModeU: SamplerAddressMode
    /// Addressing along the v coordinate.
    public var addressModeV: SamplerAddressMode
    /// Addressing along the w coordinate.
    public var addressModeW: SamplerAddressMode

    /// Creates independent filtering and addressing state.
    /// - Parameters:
    ///   - minFilter: Filter used while shrinking.
    ///   - magFilter: Filter used while enlarging.
    ///   - mipFilter: Filter used between mip levels.
    ///   - addressModeU: Behaviour outside the u-coordinate range.
    ///   - addressModeV: Behaviour outside the v-coordinate range.
    ///   - addressModeW: Behaviour outside the w-coordinate range.
    public init(
        minFilter: SamplerFilter = .nearest,
        magFilter: SamplerFilter = .nearest,
        mipFilter: SamplerFilter = .nearest,
        addressModeU: SamplerAddressMode = .clampToEdge,
        addressModeV: SamplerAddressMode = .clampToEdge,
        addressModeW: SamplerAddressMode = .clampToEdge
    ) {
        self.minFilter = minFilter
        self.magFilter = magFilter
        self.mipFilter = mipFilter
        self.addressModeU = addressModeU
        self.addressModeV = addressModeV
        self.addressModeW = addressModeW
    }
}

/// Texture sample reconstruction filter.
public enum SamplerFilter: Hashable, Sendable {
    /// Selects the nearest sample without interpolation.
    case nearest
    /// Interpolates adjacent samples linearly.
    case linear
}

/// Behaviour for texture coordinates outside the normal range.
public enum SamplerAddressMode: Hashable, Sendable {
    /// Samples the nearest edge value.
    case clampToEdge
    /// Wraps coordinates to the opposite edge.
    case `repeat`
    /// Wraps while mirroring alternate repetitions.
    case mirrorRepeat
}
