public protocol RenderComposition {
    func prepare() throws
    func encodeBackground(into encoder: any RenderEncoder)
    func encodeOverlay(into encoder: any RenderEncoder)
}
