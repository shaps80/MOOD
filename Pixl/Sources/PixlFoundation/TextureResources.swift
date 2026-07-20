import Atomics
import PixlPlatform
import Swift

private let nextTextureResourceIdentity = ManagedAtomic<UInt64>(1)

/// Opaque identity used to resolve one logical texture asset.
public struct TextureResourceID: Hashable, Sendable {
    package let rawValue: UInt64

    package init(rawValue: UInt64) {
        precondition(rawValue != 0, "Texture resource identity must be nonzero")
        self.rawValue = rawValue
    }
}

/// Runtime-owned mapping from logical texture identities to platform resources.
public final class TextureResources {
    private let device: any Device
    private var textures: [TextureResourceID: Texture] = [:]

    public init(device: any Device) {
        self.device = device
    }

    deinit {
        for texture in textures.values {
            device.destroy(texture)
        }
    }

    public func insert(_ texture: Texture) -> TextureResourceID {
        let identity = nextTextureResourceIdentity
            .loadThenWrappingIncrement(ordering: .relaxed)
        precondition(
            identity != 0,
            "Texture resource identity space is exhausted"
        )
        let id = TextureResourceID(rawValue: identity)
        textures[id] = texture
        return id
    }

    public func texture(for id: TextureResourceID) -> Texture? {
        textures[id]
    }

    /// Replaces a resolved resource while preserving its logical identity.
    /// The store assumes ownership of `texture` only when the ID is valid.
    @discardableResult
    public func replace(
        _ texture: Texture,
        for id: TextureResourceID
    ) -> Bool {
        guard let previous = textures[id] else { return false }
        textures[id] = texture
        device.destroy(previous)
        return true
    }

    @discardableResult
    public func remove(_ id: TextureResourceID) -> Bool {
        guard let texture = textures.removeValue(forKey: id) else {
            return false
        }
        device.destroy(texture)
        return true
    }
}
