import Swift

/// A GPU submission lane for recorded frame work.
public protocol Queue {
    /// Submits every recorded pass and command in a frame in order.
    /// - Parameter frame: Frame whose current recording is submitted.
    /// - Throws: ``QueueError`` when native command recording or resource validation fails.
    func submit(_ frame: Frame) throws(QueueError)
}

/// A failure while lowering or submitting a recorded frame.
public enum QueueError: Error, Hashable, Sendable {
    /// A native command buffer or command list could not be created.
    case commandBufferCreationFailed
    /// A native pass encoder could not be created.
    case encoderCreationFailed
    /// A recorded handle is stale, destroyed, or belongs to another device.
    case invalidResource
}
