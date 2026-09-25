import PixlProfiler

/// Fit the selected tick's actual CPU/GPU span, independent of cadence or pause gaps.
enum ProfileFrameWindow {
    static func range(in snapshot: ProfileSnapshot,
                      frame: ProfileSnapshot.Segment?) -> ClosedRange<Double> {
        guard let frame else { return snapshot.start...(snapshot.start + 0.001) }
        let end = max(frame.end, snapshot.correlationEnds[frame.correlation] ?? frame.end)
        // Keep a nonzero drawing scale for a zero-duration clock sample.
        return frame.start...max(frame.start + 1e-9, end)
    }
}
