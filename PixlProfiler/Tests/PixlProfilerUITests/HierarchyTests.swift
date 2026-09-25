import Testing
import PixlProfiler
@testable import PixlProfilerUI

struct HierarchyTests {
    @Test func pausedDrillDownPreservesOwnershipAndRestoresRange() {
        let snapshot = capture()
        let frame = snapshot.frames.first!
        let dispatch = snapshot.segments.first { $0.scope == 2 }!
        let worker = snapshot.segments.first { $0.scope == 3 }!
        #expect(snapshot.parents[dispatch.id] == frame.id)
        #expect(snapshot.parents[worker.id] == dispatch.id)
        let collapsed = ProfileTimeline(snapshot: snapshot, frame: frame, expanded: [])
        #expect(collapsed.lanes.count == 1)
        #expect(collapsed.lanes[0].rows.flatMap(\.segments).map(\.scope) == [1])
        let first = ProfileTimeline(snapshot: snapshot, frame: frame, expanded: [frame.identity])
        #expect(first.lanes[0].rows.first?.segments.first?.scope == 1)
        #expect(first.lanes[0].rows.last?.segments.first?.scope == 2)
        let nested = ProfileTimeline(snapshot: snapshot, frame: frame, expanded: [frame.identity, dispatch.identity])
        #expect(nested.bounds == dispatch.start...dispatch.end)
        #expect(nested.lanes.first?.name == "Render")
        #expect(nested.lanes.last?.rows.first?.segments.first?.scope == 3)
        #expect(first.bounds == frame.start...frame.end)
        var live = snapshot
        live.isRecording = true
        let running = ProfileTimeline(snapshot: live, frame: frame, expanded: [frame.identity, dispatch.identity])
        #expect(running.path.isEmpty)
        #expect(running.lanes.count == 2)
        #expect(running.lanes.map(\.name) == ["CPU", "GPU"])
        #expect(running.lanes[0].rows[0].segments.map(\.scope) == [1])
        #expect(running.lanes[1].rows[0].segments.isEmpty)
        #expect(running.bounds == collapsed.bounds)
    }

    @Test func identityBasedFocusRejectsNonRootSelection() {
        let snapshot = capture()
        let frame = snapshot.frames.first!
        let dispatch = snapshot.segments.first { $0.scope == 2 }!
        // Navigation refers to interval identity, not mutable array positions.
        let timeline = ProfileTimeline(snapshot: snapshot, frame: frame, expanded: [frame.identity, dispatch.identity])
        #expect(timeline.path.map(\.identity) == [frame.identity, dispatch.identity])
        // A stale key from a different frame cannot fabricate a child relationship.
        let invalid = ProfileTimeline(snapshot: snapshot, frame: frame, expanded: [dispatch.identity])
        #expect(invalid.path.isEmpty)
    }

    @Test func explicitParentsKeepOverlappingGPUStagesAsSiblingsAndOwnWaits() {
        let frame = ProfileScope(10, "GPU frame", kind: .gpuFrame)
        let a = ProfileScope(11, "A", parentScope: 10)
        let b = ProfileScope(12, "B", parentScope: 10)
        let wait = ProfileScope(13, "Wait", kind: .wait, parentScope: 10)
        let session = ProfileSession(scopes: [frame, a, b, wait])
        let recorder = session.prepare(ProfileTrack(1, "GPU"))
        session.resume()
        let start = ContinuousClock.now
        for (scope, end) in [(frame, 100), (a, 90), (b, 80), (wait, 70)] {
            recorder.record(scope, start: start, end: start.advanced(by: .microseconds(end)),
                            generation: recorder.generation, correlation: 1)
        }
        let snapshot = session.snapshot()
        let parent = snapshot.segments.first { $0.scope == 10 }!
        #expect(snapshot.children[parent.id]?.count == 3)
        #expect(snapshot.segments.filter { $0.id != parent.id }.allSatisfy { snapshot.parents[$0.id] == parent.id })
    }

    @Test func liveTotalsExcludeChildStagesAndKeepTwoLanesWhenEmpty() {
        let cpu = ProfileScope(1, "Frame", kind: .frame)
        let gpu = ProfileScope(2, "GPU frame", kind: .gpuFrame)
        let stage = ProfileScope(3, "Preparation", parentScope: 2)
        let session = ProfileSession(scopes: [cpu, gpu, stage])
        let owner = session.prepare(ProfileTrack(1, "Render"))
        let device = session.prepare(ProfileTrack(2, "GPU"))
        session.resume()
        let start = ContinuousClock.now
        owner.record(cpu, start: start, end: start.advanced(by: .milliseconds(2)), generation: owner.generation, correlation: 1)
        device.record(gpu, start: start, end: start.advanced(by: .milliseconds(8)), generation: device.generation, correlation: 1)
        device.record(stage, start: start, end: start.advanced(by: .milliseconds(5)), generation: device.generation, correlation: 1)
        let snapshot = session.snapshot()
        let timeline = ProfileTimeline(snapshot: snapshot, frame: snapshot.frames.first, expanded: [])
        #expect(timeline.lanes.map(\.name) == ["CPU", "GPU"])
        #expect(timeline.lanes.flatMap(\.rows).flatMap(\.segments).map(\.scope) == [1, 2])
        var empty = ProfileSnapshot()
        empty.isRecording = true
        let pending = ProfileTimeline(snapshot: empty, frame: nil, expanded: [])
        #expect(pending.lanes.count == 2)
        #expect(pending.lanes.allSatisfy { $0.rows.count == 1 && $0.rows[0].segments.isEmpty })
    }

    @Test func idleWaitsDoNotObscureCPUFrameOrAffectItsFocus() {
        let frame = ProfileScope(1, "Frame", kind: .frame)
        let sim = ProfileScope(2, "Simulation", parentScope: 1)
        let idle = ProfileScope(3, "Mailbox wait", kind: .wait)
        let spin = ProfileScope(4, "Spin for jobs", kind: .wait)
        let gpu = ProfileScope(5, "GPU frame", kind: .gpuFrame)
        let resource = ProfileScope(6, "Resource wait", kind: .wait, parentScope: 1)
        let session = ProfileSession(scopes: [frame, sim, idle, spin, gpu, resource])
        let cpu = session.prepare(ProfileTrack(0, "CPU"))
        let worker = session.prepare(ProfileTrack(1, "Worker"))
        let device = session.prepare(ProfileTrack(2, "GPU"))
        session.resume()
        let start = ContinuousClock.now
        func record(_ recorder: ProfileRecorder, _ scope: ProfileScope, _ a: Int, _ b: Int, _ id: UInt64 = 1) {
            recorder.record(scope, start: start.advanced(by: .microseconds(a)), end: start.advanced(by: .microseconds(b)), generation: recorder.generation, correlation: id)
        }
        record(cpu, frame, 0, 209)
        record(cpu, sim, 0, 100)
        record(cpu, resource, 100, 209)
        record(cpu, idle, 209, 16_481, 0)
        record(worker, spin, 0, 33_240, 0)
        record(device, gpu, 734, 1351)
        session.freeze()
        let snapshot = session.snapshot()
        let capturedFrame = snapshot.frames[0]
        let collapsed = ProfileTimeline(snapshot: snapshot, frame: capturedFrame, expanded: [])
        #expect(collapsed.lanes.flatMap(\.rows).flatMap(\.segments).map(\.scope) == [1, 5])
        let focused = ProfileTimeline(snapshot: snapshot, frame: capturedFrame, expanded: [capturedFrame.identity])
        #expect(abs(focused.bounds.upperBound - focused.bounds.lowerBound - 0.000209) < 1e-9)
        #expect(focused.lanes.flatMap(\.rows).flatMap(\.segments).map(\.scope) == [1, 2, 6])
        #expect(snapshot.segments.count == 6) // Capture retains idle data.
    }

    @Test func gpuStagesStayUnderTheirFrameDespiteTimestampOverhang() {
        let frame = ProfileScope(1, "CPU", kind: .frame)
        let gpu = ProfileScope(2, "GPU frame", kind: .gpuFrame)
        let vertex = ProfileScope(3, "Vertex", parentScope: 2)
        let fragment = ProfileScope(4, "Fragment", parentScope: 2)
        let session = ProfileSession(scopes: [frame, gpu, vertex, fragment])
        let cpu = session.prepare(ProfileTrack(1, "CPU"))
        let device = session.prepare(ProfileTrack(2, "GPU"))
        session.resume()
        let start = ContinuousClock.now
        func record(_ recorder: ProfileRecorder, _ scope: ProfileScope, _ a: Int, _ b: Int) {
            recorder.record(scope, start: start.advanced(by: .microseconds(a)), end: start.advanced(by: .microseconds(b)), generation: recorder.generation, correlation: 1)
        }
        record(cpu, frame, 0, 100)
        record(device, vertex, 190, 250)
        record(device, fragment, 240, 810)
        session.freeze()
        var snapshot = session.snapshot()
        // Partial completion delivery must not promote declared children to roots.
        var collapsed = ProfileTimeline(snapshot: snapshot, frame: snapshot.frames.first, expanded: [])
        #expect(collapsed.lanes.flatMap(\.rows).flatMap(\.segments).map(\.scope) == [1])
        // Late external records use the original submission generation.
        device.record(gpu, start: start.advanced(by: .microseconds(200)), end: start.advanced(by: .microseconds(800)), generation: device.generation - 1, correlation: 1)
        snapshot = session.snapshot()
        let parent = snapshot.segments.first { $0.scope == 2 }!
        #expect(snapshot.children[parent.id]?.count == 2)
        collapsed = ProfileTimeline(snapshot: snapshot, frame: snapshot.frames.first, expanded: [])
        #expect(collapsed.lanes.flatMap(\.rows).flatMap(\.segments).map(\.scope) == [1, 2])
        let expanded = ProfileTimeline(snapshot: snapshot, frame: snapshot.frames.first, expanded: [parent.identity])
        #expect(Set(expanded.lanes.flatMap(\.rows).flatMap(\.segments).map(\.scope)) == [2, 3, 4])
    }

    private func capture() -> ProfileSnapshot {
        let frame = ProfileScope(1, "Frame", kind: .frame)
        let dispatch = ProfileScope(2, "Dispatch")
        let batch = ProfileScope(3, "Batch", parentScope: 2)
        let session = ProfileSession(scopes: [frame, dispatch, batch])
        let owner = session.prepare(ProfileTrack(1, "Render"))
        let worker = session.prepare(ProfileTrack(2, "Worker"))
        session.resume()
        let start = ContinuousClock.now
        func record(_ recorder: ProfileRecorder, _ scope: ProfileScope, _ a: Int, _ b: Int) {
            recorder.record(scope, start: start.advanced(by: .microseconds(a)), end: start.advanced(by: .microseconds(b)), generation: recorder.generation, correlation: 1)
        }
        record(owner, frame, 0, 100)
        record(owner, dispatch, 10, 80)
        record(worker, batch, 20, 40)
        session.freeze()
        return session.snapshot()
    }
}
