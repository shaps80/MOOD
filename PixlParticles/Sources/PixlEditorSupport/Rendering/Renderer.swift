import PixlRenderer

public final class Renderer: RenderComposition {
    public var frame = Frame()

    private let guides: GuidePass
    private let wireVolumes: WireVolumePass

    public init(platform: any Platform) throws {
        guides = try GuidePass(platform: platform)
        wireVolumes = try WireVolumePass(platform: platform)
    }

    public func prepare() throws {
        wireVolumes.prepare(frame: frame)
    }

    public func encodeBackground(into encoder: any RenderEncoder) {
        guides.encode(frame: frame, into: encoder)
    }

    public func encodeOverlay(into encoder: any RenderEncoder) {
        wireVolumes.encode(viewProjection: frame.viewProjection, into: encoder)
    }
}

enum EditorSupportError: Error {
    case buffer
    case pipeline
}
