import Pixl2D
import PixlFoundation

extension RenderQueue {
    /// Submits one indexed polygon with its model-to-world transform and render intent.
    /// - Parameters:
    ///   - polygon: Value-semantic polygon snapshot to submit.
    ///   - transform: Model-to-world transform captured with the polygon.
    ///   - rendering: Ordering and destination composition for this submission.
    ///   - material: Shading applied to the polygon content.
    public func submit(
        _ polygon: Polygon,
        transform: Polygon.Transform,
        rendering: RenderProperties = .init(),
        material: Pixl2D.Material = .unlit
    ) {
        let storage = polygon.geometry.storage
        let gradientSlot: UInt32
        switch polygon.paint {
        case .gradient(let gradient):
            gradientSlot = registerGradient(
                identity: gradient.storage,
                fingerprint: gradient.fingerprint,
                rgba8: gradient.rgba8
            )
        case .color, .texture:
            gradientSlot = .max
        }
        let geometry = registerPolygonGeometry(
            owner: storage,
            vertices: storage.vertices,
            indices: storage.indices,
            boundsMinimum: polygon.bounds.origin,
            boundsSize: polygon.bounds.size
        )
        submit(PolygonSubmission(
            polygon: polygon,
            geometry: geometry,
            transform: transform,
            rendering: rendering,
            material: material,
            gradientSlot: gradientSlot
        ))
    }
}
