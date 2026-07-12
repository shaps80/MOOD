import Swift

public protocol LanePartitioned: AnyObject, Sendable {
    associatedtype Element: Sendable

    var count: Int { get }
    var minimumElementsPerLane: Int { get }

    func withUnsafeMutableElements<Result>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws -> Result
    ) rethrows -> Result
}

public extension LanePartitioned {
    var minimumElementsPerLane: Int { 64 }
}

public final class Lanes: @unchecked Sendable {
    private final class Context: @unchecked Sendable {
        let execute: (Lane) -> Void

        init(execute: @escaping (Lane) -> Void) {
            self.execute = execute
        }
    }

    private enum Program: LaneProgram {
        static func execute(_ context: Context, on lane: Lane) {
            context.execute(lane)
        }
    }

    private let group: ExecutionGroup<Program>

    public init(
        topology: ExecutionTopology? = nil,
        settings: ExecutionSettings = .init()
    ) {
        group = .init(topology: topology, settings: settings)
    }

    public func run(
        preferredCount: Int? = nil,
        _ body: @Sendable (Lane) -> Void
    ) {
        let requestedCount = preferredCount ?? group.laneCount
        precondition(requestedCount > 0)

        withoutActuallyEscaping(body) { escapingBody in
            group.run(
                Context { lane in
                    escapingBody(lane)
                },
                laneCount: min(group.laneCount, requestedCount)
            )
        }
    }

    public func run<Storage: LanePartitioned>(
        for storage: Storage,
        preferredCount: Int? = nil,
        _ body: @Sendable (inout Storage.Element) -> Void
    ) {
        let requestedCount = preferredCount ?? group.laneCount
        precondition(requestedCount > 0)

        let usefulCount = max(
            1,
            (storage.count + storage.minimumElementsPerLane - 1)
                / storage.minimumElementsPerLane
        )
        let laneCount = min(group.laneCount, requestedCount, usefulCount)

        storage.withUnsafeMutableElements { elements in
            withoutActuallyEscaping(body) { escapingBody in
                group.run(
                    Context { lane in
                        for index in lane.partition(count: elements.count) {
                            escapingBody(&elements[index])
                        }
                    },
                    laneCount: laneCount
                )
            }
        }
    }
}
