# PixlMemory Roadmap

PixlMemory is an independent portable memory library. Its first production
slice exists to validate its interface, accounting, reports, and diagnostics
before it owns payload backing storage. Pixl engine integration is separate and
comes later.

## First Slice — Tracked Memory Interface

- [x] Add a standalone, standard-library-only `PixlMemory` Swift package with a
  public library product and target. It must remain platform-agnostic and import
  no Apple framework or SDK module.
- [x] Add a `Sandbox` executable product and target depending only on
  `PixlMemory`. Give it an input-driven game-style loop, representative plans,
  explicit use/release, reports, and deliberate failure actions. Do not run it
  during implementation; the developer will run it manually in Xcode.
- [x] Add decimal byte quantities with `.bytes`, `.kilobytes`, and `.megabytes`.
  Typed reservations derive byte size and alignment from Swift `MemoryLayout`.
- [x] Add named `MemoryPlan` descriptions that calculate payload, alignment
  padding, tracking metadata, and total required capacity without allocating
  payload backing storage.
- [x] Add `PlanConcurrency.single` and `.upTo(Int)`. Arena reserved capacity
  combines permanent requirements with the largest configured number of
  distinct plans.
- [x] Add the real `Arena`, nested lifetime scopes, and automatic descendant
  release. Releasing a smaller scope early makes its tracked capacity available
  for reuse; releasing a parent releases its complete scope subtree.
- [x] Add tracking-only typed and raw reservations. They enforce their real
  calculated byte/count capacities and expose explicit acquire/release
  operations so current use, reuse, and peak use can be exercised without
  allocating payload backing or retaining inserted values.
- [x] Add production capacity, plan-activation, and plan-concurrency failures.
  Diagnostics include reserved, used, requested, and required values; caller
  `#fileID` and `#line`; and a concrete minimum fix suggestion.
- [x] Add concise explicit startup, peak, plan, scope, and reservation reports.
  Tables use actual plan names, header separators, fixed-width right-aligned
  columns, decimal units, and exactly two fractional digits. Default managed
  capacity is zero. Do not add capability reporting.
- [ ] Exercise valid plans, nested scopes, early release/reuse, deliberate
  reservation overflow, and deliberate plan-concurrency overflow through
  `Sandbox` so the interface and human-readable output can receive developer
  sign-off.

## Explicitly Deferred

- Payload backing allocation and usable byte access.
- Typed buffers, pools, dense storage, and generational handles.
- Unit tests and benchmark executables.
- Game package dependencies and Pixl runtime, `Pixl.Game`, renderer, audio,
  asset, GPU, or platform integration.
