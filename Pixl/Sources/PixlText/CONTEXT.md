# PixlText Architecture and Vocabulary

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
