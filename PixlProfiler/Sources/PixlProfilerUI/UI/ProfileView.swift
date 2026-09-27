import PixlProfiler

public typealias Snapshot = ProfileSnapshot
public typealias Frame = ProfileSnapshot.Segment
public typealias Track = ProfileSnapshot.Track

public struct SnapshotLayout: Sendable {
    private let snapshot: ProfileSnapshot

    private var frames: ArraySlice<Frame> {
        snapshot.frames.suffix(20)
    }

    public init(snapshot: ProfileSnapshot) {
        self.snapshot = snapshot
    }
}

public struct TrackLayout: Sendable {
    private let track: Track

    public init(track: Track) {
        self.track = track
    }
}

import Playgrounds
#Playground {
    let work = ProfileScope(1, "Work")
    let track = ProfileTrack(1, "Thread")

    func record(_ recorder: ProfileRecorder, count: Int) {
        for i in 0..<count {
            recorder.end(recorder.begin(work, correlation: UInt64(i)))
        }
    }

    let count = 250_000
    let session = ProfileSession(scopes: [work], maximumEvents: count)
    let recorder = session.prepare(track, capacity: count)

    record(recorder, count: 1)
    session.resume()
    record(recorder, count: 100)
    _ = session.snapshot()
    session.freeze()

    session.resume()
    let start = ContinuousClock.now
    record(recorder, count: count)
    session.freeze()

    let trace = session.snapshot()
}
