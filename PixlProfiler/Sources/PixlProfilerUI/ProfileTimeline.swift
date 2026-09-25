import PixlProfiler

/// Presentation only: captured intervals remain untouched by navigation.
struct ProfileTimeline {
    struct Row: Identifiable {
        let id: String
        let segments: [ProfileSnapshot.Segment]
    }
    struct Lane: Identifiable {
        let id: Int
        let name: String
        let rows: [Row]
    }
    let bounds: ClosedRange<Double>
    let path: [ProfileSnapshot.Segment]
    let lanes: [Lane]

    init(snapshot: ProfileSnapshot, frame: ProfileSnapshot.Segment?,
         expanded: [ProfileSnapshot.Segment.Identity]) {
        var path: [ProfileSnapshot.Segment] = []
        if !snapshot.isRecording {
            for key in expanded {
                guard let id = snapshot.segmentIDsByIdentity[key], let segment = snapshot.segmentsByID[id],
                      !(snapshot.children[id] ?? []).isEmpty,
                      path.last.map({ snapshot.parents[id] == $0.id }) ?? (snapshot.parents[id] == nil)
                else { break }
                path.append(segment)
            }
        }
        self.path = path
        let full = ProfileFrameWindow.range(in: snapshot, frame: frame)
        bounds = path.last.map { $0.start...max($0.start + 1e-9, $0.end) } ?? full
        if snapshot.isRecording {
            let gpuScopes = Set(snapshot.scopes.filter { $0.kind == .gpuFrame }.map(\.id))
            let gpu = frame.flatMap { frame in
                snapshot.segments.last { $0.correlation == frame.correlation && gpuScopes.contains($0.scope) }
            }
            lanes = [
                Lane(id: frame?.track ?? -1, name: "CPU",
                     rows: [Row(id: "cpu-total", segments: frame.map { [$0] } ?? [])]),
                Lane(id: gpu?.track ?? -2, name: "GPU",
                     rows: [Row(id: "gpu-total", segments: gpu.map { [$0] } ?? [])])
            ]
            return
        }
        // Hide idle polling/spinning roots; retain waits inside actual frame work.
        let idleScopes = Set(snapshot.scopes.filter { $0.kind == .wait && $0.parentScope == nil }.map(\.id))
        // Missing/late parents do not turn explicitly owned stages into top-level groups.
        let childScopes = Set(snapshot.scopes.filter { $0.parentScope != nil }.map(\.id))
        var levels: [UInt64: Int] = [:]
        var shown: [ProfileSnapshot.Segment] = []
        if let focus = path.last {
            for (level, segment) in path.enumerated() {
                shown.append(segment); levels[segment.id] = level
            }
            for id in snapshot.children[focus.id] ?? [] {
                guard let child = snapshot.segmentsByID[id] else { continue }
                shown.append(child); levels[id] = path.count
            }
        } else {
            for track in snapshot.tracks {
                for segment in snapshot.trackSegments[track.id] ?? [] {
                    guard !idleScopes.contains(segment.scope), !childScopes.contains(segment.scope),
                          snapshot.parents[segment.id] == nil,
                          segment.end > full.lowerBound, segment.start < full.upperBound,
                          segment.correlation == frame?.correlation || segment.correlation == 0 else { continue }
                    shown.append(segment); levels[segment.id] = 0
                }
            }
        }
        let grouped = Dictionary(grouping: shown, by: \.track)
        // Keep submitting parents above their children, including other thread lanes.
        let orderedTracks = snapshot.tracks.filter { grouped[$0.id] != nil }.sorted {
            let a = (grouped[$0.id] ?? []).map { levels[$0.id] ?? 0 }.min() ?? 0
            let b = (grouped[$1.id] ?? []).map { levels[$0.id] ?? 0 }.min() ?? 0
            return a == b ? $0.id < $1.id : a < b
        }
        lanes = orderedTracks.map { track in
            let groups = Dictionary(grouping: grouped[track.id] ?? []) { levels[$0.id] ?? 0 }
            var rows: [Row] = []
            for level in groups.keys.sorted() {
                var slots: [[ProfileSnapshot.Segment]] = []
                for segment in (groups[level] ?? []).sorted(by: { $0.start < $1.start }) {
                    let index = slots.firstIndex { ($0.last?.end ?? 0) <= segment.start } ?? slots.count
                    if index == slots.count { slots.append([]) }
                    slots[index].append(segment)
                }
                for (slot, segments) in slots.enumerated() {
                    rows.append(Row(id: "\(track.id):\(level):\(slot)", segments: segments))
                }
            }
            return Lane(id: track.id, name: track.name, rows: rows)
        }
    }
}
