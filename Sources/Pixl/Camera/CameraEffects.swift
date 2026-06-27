import Swift

/// Applies presentation-only offsets to the resolved camera.
///
/// Effects are additive and last in the pipeline. They do not feed back into
/// anchor, tracking, composition, or constraints.
///
/// Pipeline position:
///
/// ```text
/// anchor -> composition -> tracking -> constraints -> effects -> camera
/// ```
///
/// Current implementation:
///
/// ```text
/// final origin = constrained origin + effects.offset
/// ```
///
/// This supports simple shake or recoil-style offsets while preserving stable
/// base camera state.
public struct CameraEffects: Equatable, Sendable {
    /// Additive world-space offset applied after constraints.
    public var offset: Vec2

    /// Creates camera effects.
    ///
    /// - Parameter offset: Additive world-space offset applied after constraints.
    public init(offset: Vec2 = .zero) {
        self.offset = offset
    }
}
