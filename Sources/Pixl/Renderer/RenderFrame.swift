import Swift

/// Platform-neutral draw data for one prepared game frame.
///
/// `RenderFrame` is the boundary between Pixl's game/render semantics and a
/// platform renderer. Pixl decides rects, UVs, colors, ordering, and batching;
/// platforms decide how to upload and draw that data.
public struct RenderFrame: Equatable, Sendable {
    public var batches: [PreparedRenderBatch]

    public init(batches: [PreparedRenderBatch] = []) {
        self.batches = batches
    }
}
