import Swift

public protocol Queue {
    func submit(_ frame: Frame) throws(QueueError)
}

public enum QueueError: Error, Hashable, Sendable {
    case commandBufferCreationFailed
    case encoderCreationFailed
    case invalidResource
    case unsupportedPass
}
