# PixlMemory Roadmap

PixlMemory is an independent, platform-agnostic Swift memory library. It owns
explicit fixed-capacity CPU storage, lifetime layouts, diagnostics, and usage
reporting. It imports no platform SDK.

## Implementation verification

- [x] Compile the `@Layout` and `@Region` consumer fixture in
  `PixlMemoryTests`, including persistent arena buffers and acquired-layout
  buffers, pools, and raw bytes.
- [x] Verify aligned arena allocation, persistent storage, one active top-level
  layout, nested acquisition, cascading release, and storage reuse.
- [ ] Verify eager/lazy preparation inheritance and that hot-path operations
  never allocate, wait, or grow implicitly.
- [x] Verify indexed-buffer initialization, bulk append/replace, mutation,
  removal, borrowing, capacity failures, and stale-scope failures.
- [x] Verify raw-buffer alignment, byte access, borrowing, capacity failures,
  and stale-scope failures.
- [x] Verify dense-pool insertion, removal, dense iteration, generational
  handles, constant-time lookup, stale-handle detection, and capacity failures.
- [x] Verify exclusive mutable borrowing, concurrent read borrowing, immediate
  contention failure, and release failure while borrowed.
- [ ] Validate raw statistics and diagnostics data. Keep report formatting out
  of correctness assertions.

## Performance

- [ ] Add standalone release benchmarks for arena operations, indexed buffers,
  raw buffers, dense pools, handle lookup, and dense iteration.
- [ ] Confirm no steady-state allocation or dynamic dispatch in hot paths.
- [ ] Compare Sandbox release resident memory against its accepted 3.60–3.80 MB
  pre-allocation CLI baseline and record accepted results in `PERF.md`.
- [ ] Establish accepted host baselines before integrating PixlMemory elsewhere.

## Deferred

- Pixl engine and `Pixl.Game` integration.
