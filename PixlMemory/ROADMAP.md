# PixlMemory Roadmap

PixlMemory is an independent, platform-agnostic Swift memory library. It owns
explicit fixed-capacity CPU storage, lifetime layouts, diagnostics, and usage
reporting. It imports no platform SDK.

## Performance

- [ ] Add standalone release benchmarks for arena operations, indexed buffers,
  raw buffers, dense pools, handle lookup, and dense iteration.
- [ ] Confirm no steady-state allocation or dynamic dispatch in hot paths.
- [ ] Compare Sandbox release resident memory against its accepted 3.60–3.80 MB
  pre-allocation CLI baseline and record accepted results in `PERF.md`.
- [ ] Establish accepted host baselines before integrating PixlMemory elsewhere.

## Deferred

- Pixl engine and `Pixl.Game` integration.
