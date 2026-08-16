import Swift

public enum RenderError: Error {
    case device
    case commandQueue
    case shaderLibrary
    case shaderFunction
    case pipeline
    case depthState
    case buffer
    case commandBuffer
}
