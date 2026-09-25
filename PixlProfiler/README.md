# PixlProfiler

Reusable Swift profiler with static definitions, preallocated recording buffers,
and deferred trace processing. Two library products:

- `PixlProfiler`: platform-agnostic recording and renderer-independent snapshots.
  Imports Swift's Synchronization module; no Foundation, Dispatch, SwiftUI or Metal.
- `PixlProfilerUI`: optional SwiftUI timeline and background consumer, guarded by
  `canImport(SwiftUI)`. Requires macOS 15 / iOS 18 or corresponding platforms.

## Recording

Define the complete schema statically. IDs must be unique within a session.
Definitions cannot be registered after the first capture starts.

```swift
import PixlProfiler

enum Trace {
    static let render = ProfileTrack(1, "Render")
    static let frame = ProfileScope(1, "Frame", kind: .frame)
    static let update = ProfileScope(2, "Update")
    static let scopes = [frame, update]
}

// Setup only: force static initialization, construct the name lookup table,
// allocate and initialize every slot, then distribute handles to their threads.
let session = ProfileSession(scopes: Trace.scopes)
let recorder = session.prepare(Trace.render)
session.resume()

// Recording: explicit boundaries, raw clock instants and integer identifiers.
let frame = recorder.begin(Trace.frame, correlation: frameNumber)
let update = recorder.begin(Trace.update, correlation: frameNumber)
// Perform the actual update.
recorder.end(update)
recorder.end(frame)
```

A recorder is assigned to ONE producer. Register fixed worker instances during
setup with `prepare(Trace.worker, instance: index)`. Handles retain their backing
storage safely; the events and tokens contain no reference-counted payloads.
No name lookup, allocation, locking, thread lookup, registration or retries occur
in `begin`/`end`. Buffer overflow drops the event and increments a counter.
The disabled path avoids clock reads. Timestamp reads and atomics still cost time.

For callback tracks without thread affinity, use `concurrent: true`. Writers make
one atomic claim attempt, dropping on contention rather than blocking. Ordinary
thread tracks use single-producer publication without a producer claim.

External work can use `record(_:start:end:generation:correlation:)`. Save the
recorder's generation at submission, never at callback time. Transfer timestamps
into the same clock domain before recording. Old-generation callbacks cannot enter
a resumed capture. Mark complete GPU command intervals with `.gpuFrame` so the
viewer can select the latest frame whose GPU interval is available.

## Ownership and freezing

After setup, exactly ONE owner must call `resume`, `freeze` and `snapshot`.
Recording runs concurrently with that owner. `ProfileSession` is unchecked Sendable
because it enforces ownership by API contract rather than an actor on the hot path.
Do not mutate/control/drain a session from arbitrary threads.

`freeze` disables new CPU intervals; unfinished CPU scopes crossing the cutoff
are omitted. Already-submitted external intervals from that generation may execute and
finish later, including GPU work queued behind earlier submissions. A subsequent snapshot includes those results, even when their
end is after the freeze boundary. Resume starts a new generation and reclaims
old queued events before accepting new work.

`snapshot()` performs sorting, nesting/lane placement and statistics. It allocates
and must NEVER run on render/simulation workers. Default retained history: three
seconds, capped at 100,000 events. Each track defaults to 16,384 queued events.
Dropped recordings and history trimming are reported independently.

## SwiftUI

```swift
import PixlProfilerUI

// Main actor, after preparing every recorder. This transfers session control
// and draining to the controller's serial background queue.
let controller = ProfileController(session: session)
controller.resume()
// Show controller.snapshot using ProfilerView(snapshot: controller.snapshot).
// Pause application playback:
controller.freeze()
```

Do not also control/drain the session yourself when using `ProfileController`.
Its consumer publishes prepared snapshots roughly once per second. Freezing cancels
that timer. Prepare `controller.externalCompletionHandler()` once and call it after
recording external results: frozen snapshots then update through a coalesced
notification, with no paused polling. Keep the controller alive independently of
whether the viewer is on screen.

The viewer shows actual CPU-frame spans, nested scopes, each prepared thread and
GPU overlap. Select frames using the overview/previous/next controls, expand tracks for screenshots, and select a segment for details. Statistics report
inclusive per-scope mean, nearest-rank p95 and maximum over retained events.
They are not additive across nested scopes or overlapping GPU stages. Frame bars
measure instrumented CPU spans, not presentation cadence. Gaps are uninstrumented;
thread intervals do not establish OS scheduling, CPU utilization or core affinity.

## Validation

`swift test --sanitize thread` covers concurrent publication/draining, callback
contention, nesting, overflow, storage lifetime and freeze/resume generations.

On macOS, `.scripts/benchmark-recording` compiles the real core sources directly
with release WMO. A malloc interposer verifies no recording-thread heap allocations
and includes a positive control. It reports disabled/enabled completed-scope cost;
setup, processing and rendering are excluded. Run sequentially with other performance
work stopped. Host results are not device or WebAssembly performance evidence.

The editor integration lives in `PixlParticlesUI/Views/Profiler`. Metal exposes
calibrated intervals through a generic renderer API; neither particle simulation
nor renderer libraries depend on this package. The current CPU render scope includes
encoding plus drawable/frame-resource waits; it does not pretend to separate them.

The timeline fills the available viewer width with the selected tick's actual
span, from CPU frame start through its last CPU/GPU completion. Fast and slow
ticks both fill the width; the ruler shows their measured duration. There are
no zoom/pan controls or horizontal timeline scrolling.

Paused viewers start with root scopes. Tapping a parent reveals its immediate
children below it and fits its interval to the viewport. Ancestors remain collapse
targets. Live snapshots show exactly two fixed-height CPU/GPU total lanes, with no history,
navigation or footer. Pending results retain empty lanes rather than changing height. Hierarchy is built
by the deferred consumer; static `parentScope` metadata expresses cross-thread
ownership and distinguishes overlapping siblings. Without it, same-thread
containment supplies the default hierarchy. Missing or ambiguous explicit parents
remain unresolved and their children stay hidden at the top level. GPU frame
ownership uses the declared parent, frame correlation and track; calibrated stage
timestamps need not fit exactly inside command-buffer timestamps. `ProfileController.suspend()` stops hidden consumer work, including
late-completion refreshes; application producers must also bypass their hooks.
