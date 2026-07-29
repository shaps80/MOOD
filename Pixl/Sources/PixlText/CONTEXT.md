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

Glyph clusters map UTF-8 source ranges to glyph-index ranges. The initial pass forms source clusters from Swift extended grapheme clusters. Normalization may collapse several source scalars into one glyph candidate; later shaping may also expand one source cluster into several glyphs. The range-to-range representation supports both without changing source identity.

Canonical normalization precedes font-specific shaping. PixlText implements NFC directly from checked-in Unicode 16.0 tables; it does not depend on Foundation or platform normalization. Tables are generated offline only when intentionally upgrading Unicode, then reused as static read-only runtime data. The algorithm writes into caller-owned reusable buffers and preserves each original grapheme's UTF-8 source range when several source scalars compose into one normalized scalar.

OpenType `GSUB` and `GPOS` are the primary cross-platform shaping formats. Fonts without those tables currently fall back to scalar-to-glyph mapping and advances. Apple AAT (`morx`/`kerx`) and Graphite shaping are unsupported; they are not initial implementation targets.

Base GSUB lookup types 1–8 and GPOS lookup types 1–9 are parsed into flat native-endian plans and executed without hot-path collection allocation. This includes single, multiple, alternate, ligature, contextual, chained-contextual, reverse-contextual, pair, cursive, mark attachment, and extension lookups. GDEF glyph classes, mark attachment classes, mark filtering sets, and lookup flags participate in matching. Substitutions preserve source ranges and ligature-component metadata needed by later mark attachment.

This lookup coverage is the mechanical OpenType Layout foundation, not a complete script-shaping engine. Script-specific preprocessing, reordering, joining-form masks, per-glyph feature masks, explicit language selection, variable-font FeatureVariations/ItemVariationStore evaluation, and size-specific Device adjustments remain later stages.

Script detection uses a generated Unicode 16.0 Script-property range table. GSUB selection resolves the matching OpenType Script table, its requested or default language system, enabled features, and ordered lookups. Language cannot be inferred reliably from scalar content; the current pipeline uses each script's default language system until language metadata is supplied explicitly by a future run input.

Shaping separates cold plan compilation from hot run execution. A plan contains flat, immutable, native-endian lookup and rule columns indexed by integer ranges. Run execution scans glyphs per active lookup, binary-searches candidate rules, and compacts shrinking substitutions with read/write cursors; it does not scan every rule across the run, allocate temporary collections, or shift an array suffix per ligature. Plan caching and buffer capacity are implementation concerns hidden above the eventual public text API.

OpenType positioning runs after substitution. Positioning writes font-unit placement and advance deltas directly into the shaping glyph buffer; scaling and final baseline positions remain a later layout step. Parsed positioning data and plans are immutable, indexed cold-path data. Hot positioning performs binary searches, direct matrix indexing, and sequential buffer traversal without allocation.

Shaping workspaces are call-local noncopyable values initially. They own exact contiguous glyph and scratch buffers, grow geometrically when required, and release deterministically. Capacity is never exposed through the eventual public text API. A future document, layout session, or execution lane may retain and reuse the same workspace without changing algorithm inputs or public ownership.

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
