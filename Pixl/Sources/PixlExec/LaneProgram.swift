import Swift

package protocol LaneProgram: SendableMetatype {
    associatedtype Context: AnyObject, Sendable

    static func execute(_ context: Context, on lane: Lane)
}
