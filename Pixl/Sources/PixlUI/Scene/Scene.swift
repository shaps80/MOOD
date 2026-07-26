import PixlGraphics
import Swift

public final class Scene<Content: View> {
    package let content: Content
    private let stateStore = _StateStore()
    package var generation: UInt64 { stateStore.generation }
    package var preparedGeneration: UInt64?
    package var preparedDisplayScale: Float?
    package var preparedSize: Size?
    package var root: ViewGraphRoot<Content>?
    package var layout: ViewLayout?

    public init(_ content: Content) {
        self.content = content
    }

    public init(
        @ContentBuilder content: () -> Content
    ) {
        self.content = content()
    }

    package func invalidate() {
        stateStore.invalidate()
    }

    package func prepare(
        size: Size,
        displayScale: Float,
        resolveImage: (String) throws -> TextureAsset
    ) throws -> (root: ViewGraphRoot<Content>, layout: ViewLayout) {
        precondition(
            size.width.isFinite && size.height.isFinite
                && size.width >= 0 && size.height >= 0,
            "Scene size must be finite and nonnegative"
        )
        precondition(
            displayScale.isFinite && displayScale > 0,
            "displayScale must be finite and greater than zero"
        )

        let needsGraph = root == nil
            || preparedGeneration != generation
            || preparedDisplayScale != displayScale

        if needsGraph {
            root = ViewGraph.build(
                content,
                displayScale: displayScale,
                stateStore: stateStore
            )
            for index in root!.graph.primitives.indices {
                guard case var .image(image) = root!.graph.primitives[index]
                else { continue }
                image.asset = try resolveImage(image.name)
                root!.graph.primitives[index] = .image(image)
            }
            preparedGeneration = generation
            preparedDisplayScale = displayScale
            preparedSize = nil
            layout = nil
        }

        if layout == nil || preparedSize != size {
            layout = root!.layout(in: size, displayScale: displayScale)
            preparedSize = size
        }

        return (root!, layout!)
    }
}
