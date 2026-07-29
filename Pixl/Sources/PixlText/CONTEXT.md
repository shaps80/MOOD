# PixlText Architecture and Vocabulary

## Target and Scope

PixlText is one Swift target. Its internals are separated by ownership and responsibility rather than by additional targets.

Current work focuses exclusively on low-level text algorithms and records: Unicode classification, shaping, glyph positioning, line layout, paragraph layout, and font data access. High-level convenience APIs, declarative state, delegation, editing abstractions, glyph imaging, and presentation are deferred.

`String` is the input boundary. Core algorithms borrow its UTF-8 and Unicode-scalar views; they do not own, decode, or copy source text. A caller-owned temporary source-offset map may be written only where an algorithm needs to map results back to the source string.

The current core ends at shaped glyph positions, line records, and paragraph geometry. Glyph rasterisation, MSDF generation, atlas packing, and all presentation are separate future subsystems in the same target.

The low-level core has no hidden cache ownership or per-call allocation. It operates on explicit inputs and caller-owned reusable storage. Font registries, parsed font ownership, and caches belong above the core algorithms.

Public core records are struct-first. Use copy-on-write backing only where a large immutable value benefits from shared storage; introduce reference types only when stable identity, mutable ownership, or extension points require them.

Font vocabulary is text-engine-native and direct. It does not mirror host UI-framework font names or types.

## Fonts

`SFNT.Registry` is an explicit stateful support type. It owns registered SFNT bytes and their parsed face records. Registration is a cold path; measurement and shaping read the registry through compact face identities without file access or hidden cache work.

`SFNT.Face` is a registered, parsed, size-independent SFNT file. It exposes its identity, face metrics, glyph count, and table count.

`SFNT.FaceMetrics` scales directly to `SFNT.Metrics` for an explicit positive size.

`Font` is the public, declarative value. It wraps an internal `Font.Descriptor`, initially containing a source, size, canonical weight, and slant. `Font.system(size:weight:)`, `.italic()`, `.bold()`, and `.weight(_:)` return derived values. An internal process-wide `Font.Registry` owns SFNT registration; its current system source lazily loads the Zapfino probe face once. Resolved values must not create registries or reread font files in hot paths.

`SFNT.Registry` and every other SFNT type are internal implementation details. Any future public font-probing API will use purpose-built higher-level types instead.

The first SFNT parser supports the metrics needed for real measurement: `head`, `hhea`, `maxp`, `hmtx`, and Unicode `cmap` format 4 or 12 tables. It is validated against the locally installed Zapfino font.

The first measurement slice maps Unicode scalars to glyph IDs and scaled advances for one unshaped run. A temporary package-only `Font.forEachGlyph(in:_:)` exposes typographic bounds to the playground for visual verification without adding public low-level API.

TrueType render bounds come from `loca` and `glyf` headers. They remain distinct from typographic bounds and are scaled relative to each glyph's baseline origin.

## Deferred Glyph Imaging

The initial glyph-imaging format will be MSDF; alternate coverage and colour-glyph paths remain future decisions.

Atlas generation is dynamic and memory-only. Missing glyphs are generated and packed on first use, then cached for the process lifetime. PixlText has no compile-time asset pipeline or persistent glyph cache initially.

Generation and packing remain separate stages with explicit inputs and outputs:

```text
font data + glyph ID + generation settings
    -> glyph generation
    -> bitmap + metrics + generation identity
    -> atlas packing
    -> atlas placement + texture upload
```

This boundary allows future compile-time tooling to reuse generation and packing, serialize their outputs, and let runtime generation fill misses.

Shaping and layout depend on font metrics and glyph IDs, never atlas placement. Atlas generation and storage therefore remain replaceable infrastructure.

## Layout Execution

PixlText depends on PixlConcurrency. Text processing uses its lane and storage machinery rather than implementing separate scheduling, batching, or SIMD infrastructure.

The initial implementation uses one lane. Increasing the lane count later must not require restructuring text storage or processing stages.

Data-oriented design is a primary constraint. Hot processing operates over contiguous, cache-aligned buffers suitable for bulk classification, scanning, and SIMD where the work permits it. Concurrency remains an internal implementation detail rather than part of PixlText's public API.
