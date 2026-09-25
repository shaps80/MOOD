extension ProfileSnapshot {
    /// Same-thread lexical containment; explicit schema edges can cross threads.
    /// Ambiguous cross-thread candidates remain roots rather than inventing ownership.
    mutating func buildHierarchy() {
        let definitions = Dictionary(uniqueKeysWithValues: scopes.map { ($0.id, $0) })
        var active: [Int: [Segment]] = [:]
        struct Group: Hashable { let scope: UInt32; let correlation: UInt64 }
        var byScope: [Group: [Segment]] = [:]
        for segment in segments { byScope[Group(scope: segment.scope, correlation: segment.correlation), default: []].append(segment) }
        for segment in segments {
            segmentsByID[segment.id] = segment
            segmentIDsByIdentity[segment.identity] = segment.id
            var candidates = active[segment.track, default: []].filter { $0.end > segment.start }
            active[segment.track] = candidates
            let kind = definitions[segment.scope]?.kind
            if kind != .frame && kind != .gpuFrame,
               kind != .wait || definitions[segment.scope]?.parentScope != nil {
                if let explicit = definitions[segment.scope]?.parentScope {
                    let gpuParent = definitions[explicit]?.kind == .gpuFrame
                    candidates = (byScope[Group(scope: explicit, correlation: segment.correlation)] ?? []).filter {
                        if gpuParent {
                            // Counter calibration and command-buffer timestamps can overhang.
                            // Ownership is the declared GPU frame on this track, not containment.
                            return segment.correlation != 0 && $0.track == segment.track
                        }
                        return $0.start <= segment.start && $0.end >= segment.end
                    }
                    if candidates.count != 1 { candidates = [] }
                } else {
                    candidates = candidates.filter {
                        $0.correlation == segment.correlation && $0.end >= segment.end
                            && definitions[$0.scope]?.kind != .wait
                    }
                }
                if let parent = candidates.min(by: { $0.duration < $1.duration }), parent.id != segment.id {
                    parents[segment.id] = parent.id
                    children[parent.id, default: []].append(segment.id)
                }
            }
            active[segment.track, default: []].append(segment)
        }
    }
}
