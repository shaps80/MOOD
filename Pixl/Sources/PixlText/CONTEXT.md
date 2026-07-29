# PixlText Architecture and Vocabulary

## Target and Scope

PixlText is one Swift target. Its internals are separated by ownership and responsibility rather than by additional targets.

Current work focuses exclusively on low-level text algorithms and records: decoding, classification, shaping, glyph positioning, line layout, paragraph layout, font data, and atlas generation. High-level convenience APIs, declarative state, delegation, and editing abstractions are deferred.

The low-level core has no hidden cache ownership or per-call allocation. It operates on explicit inputs and caller-owned reusable storage. Font registries, parsed font ownership, and caches belong above the core algorithms.

Public core records are struct-first. Use copy-on-write backing only where a large immutable value benefits from shared storage; introduce reference types only when stable identity, mutable ownership, or extension points require them.

Font vocabulary is text-engine-native and direct. It does not mirror host UI-framework font names or types.

## Glyph Atlas

PixlText renders glyphs from an MSDF atlas. MSDF is the only distance-field format initially; alternate coverage and colour-glyph paths remain future decisions.

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
