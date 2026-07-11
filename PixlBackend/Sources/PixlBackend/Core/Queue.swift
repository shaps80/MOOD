import Swift

public protocol Queue {
    func submit(_ frame: Frame) throws
}

public enum QueueError: Error {
    case commandBufferCreationFailed
    case encoderCreationFailed
    case invalidResource
    case unsupportedPass
}
