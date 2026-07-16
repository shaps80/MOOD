import Swift

public struct Sampler: Hashable, Sendable {
    package let id: ResourceID
    public let descriptor: SamplerDescriptor

    package init(
        id: ResourceID,
        descriptor: SamplerDescriptor
    ) {
        self.id = id
        self.descriptor = descriptor
    }
}

public struct SamplerDescriptor: Hashable, Sendable {
    public var minFilter: SamplerFilter
    public var magFilter: SamplerFilter
    public var mipFilter: SamplerFilter
    public var addressModeU: SamplerAddressMode
    public var addressModeV: SamplerAddressMode
    public var addressModeW: SamplerAddressMode

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

public enum SamplerFilter: Hashable, Sendable {
    case nearest
    case linear
}

public enum SamplerAddressMode: Hashable, Sendable {
    case clampToEdge
    case `repeat`
    case mirrorRepeat
}
