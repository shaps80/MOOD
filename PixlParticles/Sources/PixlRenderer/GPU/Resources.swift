import Swift

public protocol Buffer: AnyObject {
    var length: Int { get }
    func withMutableBytes(
        _ body: (UnsafeMutableRawBufferPointer) -> Void
    )
}

public protocol ComputePipeline: AnyObject {}
public protocol RenderPipeline: AnyObject {}
public protocol DepthState: AnyObject {}
public protocol RenderTarget: AnyObject {}
