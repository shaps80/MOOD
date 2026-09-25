#if canImport(SwiftUI)
import SwiftUI
import PixlProfiler

/// Viewer owns navigation only. Capture and hierarchy are prepared off-thread.
public struct ProfilerView: View {
    public let snapshot: ProfileSnapshot
    @Namespace private var namespace
    @State private var selectedFrame: UInt64?
    @State private var expanded: [ProfileSnapshot.Segment.Identity] = []
    @State private var selectedSegment: ProfileSnapshot.Segment?
    public init(snapshot: ProfileSnapshot) { self.snapshot = snapshot }
    private var frames: [ProfileSnapshot.Segment] { Array(snapshot.frames.suffix(20)) }
    private var frame: ProfileSnapshot.Segment? {
        if !snapshot.isRecording, let selected = frames.first(where: { $0.correlation == selectedFrame }) { return selected }
        return frames.last { snapshot.gpuFrameIDs.contains($0.correlation) } ?? frames.last
    }
    public var body: some View {
        let timeline = ProfileTimeline(snapshot: snapshot, frame: frame, expanded: expanded)
        let fullFrame = ProfileFrameWindow.range(in: snapshot, frame: frame)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Profiler", systemImage: "waveform.path.ecg").font(.headline)
                Text(snapshot.isRecording ? "LIVE" : "PAUSED")
                    .font(.caption.monospaced())
                    .foregroundStyle(snapshot.isRecording ? .green : .orange)
                Spacer()
                if snapshot.dropped > 0 || snapshot.retainedOut > 0 {
                    Text("Dropped \(snapshot.dropped) · trimmed \(snapshot.retainedOut)")
                        .foregroundStyle(.orange).font(.caption)
                }
            }
            if !snapshot.isRecording {
                HStack {
                    if frame != nil {
                        GlassEffectContainer {
                            HStack {
                                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                                    .buttonStyle(.glass)
                                Button { move(1) } label: { Image(systemName: "chevron.right") }
                                    .buttonStyle(.glass)
                            }
                            .glassEffectUnion(id: "nav", namespace: namespace)
                            .fontWeight(.semibold).padding(5)
                            .disabled(snapshot.isRecording)
                        }
                    }

                    if let frame {
                        Text("Frame \(frame.correlation)")
                            .font(.caption.monospaced())
                    } else {
                        Text("Waiting for recorded frames")
                            .font(.caption.monospaced())
                    }

                    Spacer()

                    Text(frame == nil ? "—" : format(fullFrame.upperBound - fullFrame.lowerBound))
                        .font(.caption.monospaced())
                        .contentTransition(.numericText())
                }

                overview.frame(height: 34).allowsHitTesting(!snapshot.isRecording)
                    .padding(.bottom)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("00")
                        .font(.caption)
                        .frame(width: 145, alignment: .leading)
                        .hidden()

                    HStack {
                        ForEach(0..<5) { index in
                            if index > 0 { Spacer() }
                            Text(String(format: "%.2f", Double(index) / 4 * (timeline.bounds.upperBound - timeline.bounds.lowerBound) * 1000))
                                .font(.caption2.monospaced()).contentTransition(.numericText())
                        }
                    }
                }
                ForEach(timeline.lanes) { lane in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lane.name)
                        }
                        .font(.caption).frame(width: 145, alignment: .leading)
                        VStack(spacing: 2) {
                            ForEach(lane.rows) { row in
                                segmentRow(row, timeline: timeline).frame(height: 18)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .background(.white.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 4))
                    }
                    .frame(height: snapshot.isRecording ? 34 : nil, alignment: .top)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .allowsHitTesting(!snapshot.isRecording)
            if !snapshot.isRecording {
                ZStack(alignment: .leadingFirstTextBaseline) {
                    Text("00").hidden()
                    if !snapshot.isRecording, let segment = selectedSegment {
                        Text("\(name(segment.scope)) · \(format(segment.duration)) · range \(segment.detail)")
                    }
                }
                .font(.caption.monospaced()).textSelection(.enabled)
            }
        }
        .padding()
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .background(.bar)
        .clipShape(.rect(cornerRadius: 28))
        .allowsHitTesting(!snapshot.isRecording)
        .animation(.smooth, value: selectedFrame)
        .animation(.smooth, value: expanded)
        .animation(.smooth, value: snapshot.isRecording)
        .onChange(of: snapshot.generation) { resetNavigation() }
        .onChange(of: snapshot.isRecording) { if snapshot.isRecording { resetNavigation() } }
    }
    private func segmentRow(_ row: ProfileTimeline.Row, timeline: ProfileTimeline) -> some View {
        GeometryReader { geometry in
            let bounds = timeline.bounds
            let span = bounds.upperBound - bounds.lowerBound
            ZStack(alignment: .leading) {
                ForEach(0..<5) { index in
                    Rectangle().fill(.separator).frame(width: 1)
                        .offset(x: Double(index) / 4 * geometry.size.width)
                }
                ForEach(row.segments, id: \.identity) { segment in
                    let left = max(0, (segment.start - bounds.lowerBound) / span * geometry.size.width)
                    let right = min(geometry.size.width, (segment.end - bounds.lowerBound) / span * geometry.size.width)
                    let width = max(1, right - left)
                    let inset = min(1, (width - 1) / 2)
                    let hasChildren = !(snapshot.children[segment.id] ?? []).isEmpty
                    let isExpanded = timeline.path.contains { $0.identity == segment.identity }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(segment.scope))
                        .overlay(alignment: .leading) {
                            if width > 55 {
                                HStack(spacing: 3) {
                                    if hasChildren && !snapshot.isRecording {
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    }
                                    Text(width > 170 ? "\(name(segment.scope)) · \(format(segment.duration))" : name(segment.scope))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 10)).foregroundStyle(.black).padding(.horizontal, 3)
                            }
                        }
                        .frame(width: width - inset * 2, height: 18)
                        .clipped()
                        .contentShape(.rect)
                        .onTapGesture { tap(segment, timeline: timeline) }
                        .accessibilityLabel(name(segment.scope))
                        .accessibilityValue(format(segment.duration))
                        .accessibilityHint(hasChildren ? (isExpanded ? "Collapse" : "Expand") : "Show details")
                        .accessibilityAddTraits(.isButton)
                        // Move the visual and its hit area together.
                        .offset(x: left + inset)
                }
            }
        }
    }
    private func tap(_ segment: ProfileSnapshot.Segment, timeline: ProfileTimeline) {
        guard !snapshot.isRecording else { return }
        selectedSegment = segment
        if let index = timeline.path.firstIndex(where: { $0.identity == segment.identity }) {
            expanded = Array(timeline.path.prefix(index).map(\.identity))
        } else if !(snapshot.children[segment.id] ?? []).isEmpty {
            expanded = timeline.path.map(\.identity) + [segment.identity]
        }
    }
    private var overview: some View {
        let values = frames
        let selected = frame?.correlation
        return GeometryReader { geometry in
            Canvas { context, size in
                let maximum = max(values.map(\.duration).max() ?? 0, 0.0167)
                for (index, value) in values.enumerated() {
                    let width = size.width / Double(max(values.count, 1))
                    let height = max(4, value.duration / maximum * size.height)
                    let rect = CGRect(x: Double(index) * width, y: size.height - height,
                                      width: max(1, width - 1), height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .style(
                        value.correlation == selected ? AnyShapeStyle(.yellow) : AnyShapeStyle(.separator)))
                }
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard !snapshot.isRecording, !values.isEmpty else { return }
                let index = min(values.count - 1, max(0, Int(value.location.x / max(1, geometry.size.width) * Double(values.count))))
                selectFrame(values[index].correlation)
            })
        }
    }
    private func selectFrame(_ id: UInt64) {
        guard selectedFrame != id else { return }
        selectedFrame = id; expanded = []; selectedSegment = nil
    }
    private func move(_ delta: Int) {
        guard !snapshot.isRecording, !frames.isEmpty else { return }
        let current = frames.firstIndex { $0.correlation == frame?.correlation } ?? frames.count - 1
        selectFrame(frames[min(frames.count - 1, max(0, current + delta))].correlation)
    }
    private func resetNavigation() { selectedFrame = nil; expanded = []; selectedSegment = nil }
    private func name(_ id: UInt32) -> String { snapshot.scopes.first { $0.id == id }?.name ?? "Unknown" }
    private func color(_ id: UInt32) -> AnyShapeStyle {
        if snapshot.scopes.first(where: { $0.id == id })?.kind == .wait {
            return .init(.gray)
        }

        return .init(.white)
//        let color: Color
//        switch id % 7 {
//        case 0: color = .cyan
//        case 1: color = .mint
//        case 2: color = .orange
//        case 3: color = .purple
//        case 4: color = .yellow
//        case 5: color = .green
//        default: color = .pink
//        }
//        return .init(color.opacity(0.8))
    }
    private func format(_ seconds: Double) -> String { String(format: "%.3f ms", seconds * 1000) }
}
#endif
