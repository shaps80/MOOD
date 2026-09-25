extension ProfileSession {
    /// Consumer only. Sorting, strings, nesting and statistics happen here.
    public func snapshot() -> ProfileSnapshot {
        for buffer in buffers {
            buffer.drain { event in
                guard event.generation == generation,
                      cutoff.map({ event.external || event.end <= $0 }) ?? true else { return }
                history.append((buffer.definition.id, event))
            }
        }
        let end = max(seconds(cutoff ?? .now), history.map { seconds($0.1.end) }.max() ?? 0)
        let start = max(0, end - retention)
        history.removeAll { seconds($0.1.end) < start }
        history.sort {
            if $0.1.start != $1.1.start { return $0.1.start < $1.1.start }
            return $0.1.end > $1.1.end
        }
        if history.count > maximumEvents {
            let removed = history.count - maximumEvents
            history.removeFirst(removed); retainedOut += removed
        }
        var stacks = [[ContinuousClock.Instant]](repeating: [], count: buffers.count)
        var durations: [UInt32: [Double]] = [:]
        let definitions = Dictionary(uniqueKeysWithValues: scopes.map { ($0.id, $0) })
        var result = ProfileSnapshot()
        result.tracks = buffers.map(\.definition); result.scopes = scopes
        result.generation = generation; result.start = start; result.end = end
        result.isRecording = cutoff == nil && generation != 0
        result.dropped = totalDropped &- dropBaseline; result.retainedOut = retainedOut
        for (index, item) in history.enumerated() {
            let (track, event) = item
            guard let definition = definitions[event.scope] else { result.dropped &+= 1; continue }
            // Reuse an expired row even if a longer overlapping GPU stage
            // still occupies a deeper row. CPU parents sort before children.
            let depth = stacks[track].firstIndex { $0 <= event.start } ?? stacks[track].count
            if depth == stacks[track].count { stacks[track].append(event.end) }
            else { stacks[track][depth] = event.end }
            let a = seconds(event.start), b = seconds(event.end)
            let segment = ProfileSnapshot.Segment(id: UInt64(index), track: track, scope: event.scope,
                start: a, end: b, correlation: event.correlation, detail: event.detail, depth: depth)
            result.segments.append(segment)
            result.trackSegments[track, default: []].append(segment)
            if definition.kind == .frame { result.frames.append(segment) }
            if definition.kind == .gpuFrame { result.gpuFrameIDs.insert(event.correlation) }
            if event.correlation != 0 {
                result.correlationEnds[event.correlation] = max(result.correlationEnds[event.correlation] ?? b, b)
            }
            durations[event.scope, default: []].append(b - a)
        }
        result.statistics = durations.map { id, values in
            let sorted = values.sorted()
            return .init(id: id, count: values.count,
                         average: values.reduce(0, +) / Double(values.count),
                         p95: sorted[min(sorted.count - 1, Int((Double(sorted.count) * 0.95).rounded(.up)) - 1)],
                         maximum: sorted.last!)
        }.sorted { $0.id < $1.id }
        return result
    }
}
