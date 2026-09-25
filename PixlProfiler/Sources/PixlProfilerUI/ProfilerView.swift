#if canImport(SwiftUI)
import SwiftUI
import PixlProfiler

/// Viewer owns no recording state. It can be closed/recreated without losing capture.
public struct ProfilerView: View {
    public let snapshot: ProfileSnapshot
    @Namespace private var namespace
    @State private var selectedFrame: UInt64?
    @State private var expanded = false
    @State private var selectedSegment: ProfileSnapshot.Segment?
    public init(snapshot: ProfileSnapshot) { self.snapshot = snapshot }
    private var frames: [ProfileSnapshot.Segment] {
        // Limit navigation only; the snapshot retains the full capture.
        Array(snapshot.frames.suffix(20))
    }
    private var frame: ProfileSnapshot.Segment? {
        if let selected = frames.first(where: { $0.correlation == selectedFrame }) { return selected }
        return frames.last { snapshot.gpuFrameIDs.contains($0.correlation) } ?? frames.last
    }
    private var window: ClosedRange<Double> {
        ProfileFrameWindow.range(in: snapshot, frame: frame)
    }

    public var body: some View {
        let timeBounds = window
        let timeOrigin = frame?.start ?? timeBounds.lowerBound
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

            overview.frame(height: 34)

            HStack {
                GlassEffectContainer {
                    HStack {
                        Button { move(-1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.glass)

                        Button { move(1) } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.glass)
                    }
                    .fontWeight(.semibold)
                    .padding(5)
                    .glassEffectUnion(id: "nav", namespace: namespace)
                }
                Text(frame.map { "Frame \($0.correlation) · \(format($0.duration))" } ?? "Waiting for recorded frames")
                    .font(.caption.monospaced())
                Spacer()
                Text("\(format(timeBounds.upperBound - timeOrigin))").font(.caption.monospaced())
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Time (ms)").font(.caption).frame(width: 145, alignment: .leading)
                    HStack {
                        ForEach(0..<5) { index in
                            if index > 0 { Spacer() }
                            Text(String(format: "%.2f", (timeBounds.lowerBound - timeOrigin + Double(index) / 4 * (timeBounds.upperBound - timeBounds.lowerBound)) * 1000))
                                .font(.caption2.monospaced())
                        }
                    }.frame(maxWidth: .infinity)
                }
                ForEach(snapshot.tracks) { track in
                    HStack(alignment: .top, spacing: 8) {
                        Text(track.name).font(.caption).frame(width: 145, alignment: .leading)
                        lane(track).frame(maxWidth: .infinity)
                            .frame(height: laneHeight(track))
                    }
                }
            }
            .frame(minHeight: 110, maxHeight: 240)

            ZStack(alignment: .leadingFirstTextBaseline) {
                Text("00").hidden()
                if let segment = selectedSegment {
                    Text("\(name(segment.scope)) · \(format(segment.duration)) · range \(segment.detail)")
                }
            }
            .font(.caption.monospaced()).textSelection(.enabled)

            if expanded {
                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        ForEach(snapshot.statistics) { value in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name(value.id)).bold()
                                Text("avg \(format(value.average)) · p95 \(format(value.p95)) · max \(format(value.maximum))")
                                Text("\(value.count) samples") .foregroundStyle(.secondary)
                            }.font(.caption.monospaced())
                        }
                    }
                }

                Text("Real intervals · nested scope time is inclusive · gaps are uninstrumented · CPU lanes are threads, not cores")
                    .font(.caption2).foregroundStyle(.secondary)
            }

        }
        .padding()
        .clipShape(.rect(cornerRadius: 28))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
        .onChange(of: snapshot.generation) { selectedFrame = nil; selectedSegment = nil }
        .animation(.smooth, value: expanded)
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
                    let rect = CGRect(
                        x: Double(index) * width,
                        y: size.height - height,
                        width: max(1, width - 1),
                        height: height
                    )

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: height / 2), with: .style(
                            value.correlation == selected
                            ? AnyShapeStyle(.tint)
                            : AnyShapeStyle(.separator)
                        )
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                guard !values.isEmpty else { return }
                let index = min(values.count - 1, max(0, Int(value.location.x / max(1, geometry.size.width) * Double(values.count))))
                selectedFrame = values[index].correlation; selectedSegment = nil
            })
        }
    }
    private func visible(_ track: ProfileSnapshot.Track) -> [ProfileSnapshot.Segment] {
        let bounds = window
        return (snapshot.trackSegments[track.id] ?? []).filter { $0.end >= bounds.lowerBound && $0.start <= bounds.upperBound }
    }
    private func laneHeight(_ track: ProfileSnapshot.Track) -> Double {
        Double((visible(track).map(\.depth).max() ?? 0) + 1) * 20
    }
    private func lane(_ track: ProfileSnapshot.Track) -> some View {
        let bounds = window
        let segments = visible(track)
        return GeometryReader { geometry in
            Canvas { context, size in
                let span = bounds.upperBound - bounds.lowerBound
                for index in 0...4 {
                    var line = Path()
                    let x = Double(index) / 4 * size.width
                    line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(line, with: .style(.separator), lineWidth: 1)
                }
                for segment in segments {
                    let x = max(0, (segment.start - bounds.lowerBound) / span * size.width)
                    let right = min(size.width, (segment.end - bounds.lowerBound) / span * size.width)
                    let rect = CGRect(x: x, y: Double(segment.depth) * 20, width: max(1, right - x), height: 18)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .style(color(segment.scope)))

                    if rect.width > 55 {
                        context.draw(Text(rect.width > 170 ? "\(name(segment.scope)) · \(format(segment.duration))" : name(segment.scope)).font(.system(size: 10)).foregroundColor(.black),
                                     at: CGPoint(x: rect.minX + 3, y: rect.midY), anchor: .leading)
                    }
                }
            }
            .background(.thinMaterial)
            .clipShape(.rect(cornerRadius: 4))
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let time = bounds.lowerBound + value.location.x / max(1, geometry.size.width) * (bounds.upperBound - bounds.lowerBound)
                let depth = Int(value.location.y / 20)
                selectedSegment = segments.last { $0.depth == depth && $0.start <= time && $0.end >= time }
            })
        }
    }
    private func move(_ delta: Int) {
        let values = frames
        guard !values.isEmpty else { return }
        let current = values.firstIndex { $0.correlation == frame?.correlation } ?? values.count - 1
        selectedFrame = values[min(values.count - 1, max(0, current + delta))].correlation
        selectedSegment = nil
    }
    private func name(_ id: UInt32) -> String { snapshot.scopes.first { $0.id == id }?.name ?? "Unknown" }
    private func color(_ id: UInt32) -> AnyShapeStyle {
        if snapshot.scopes.first(where: { $0.id == id })?.kind == .wait {
            return .init(.fill)
        }

        let color: Color
        switch id % 7 {
        case 0: color = .cyan
        case 1: color = .mint
        case 2: color = .orange
        case 3: color = .purple
        case 4: color = .yellow
        case 5: color = .green
        default: color = .pink
        }
        return .init(color.opacity(0.8))
    }
    private func format(_ seconds: Double) -> String { String(format: "%.3f ms", seconds * 1000) }
}
#endif
