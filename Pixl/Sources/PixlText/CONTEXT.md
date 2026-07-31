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

Line-breaking opportunities follow Unicode 16.0 UAX #14 over the logical source text, independently of font and shaping-run boundaries. Compact generated property pages are immutable process data. The classifier writes only allowed and mandatory UTF-8 source offsets into caller-owned reusable storage; prohibited boundaries remain implicit. Width-based selection of those opportunities belongs to line layout.

Single-line composition sequentially scans shaped glyph clusters, selects the last legal opportunity fitting the available width, and never splits a cluster. A positioned line owns no glyph collections: it references shared glyph ranges and caller-owned reusable position storage. Its consumed ranges include trailing collapsible whitespace and line controls, while its visible glyph range and advance exclude trailing collapsible whitespace. If the first unbreakable segment exceeds the width, it remains intact and overflows rather than introducing an illegal break. Soft hyphens are represented as distinct discretionary opportunities for later visible-hyphen insertion.

Positioned-line metrics include advance, ascent, descent, effective leading, natural above/below extents, baseline offset, typographic bounds, resolved line-box bounds, and render bounds. Each run contributes `ascent + leading / 2` above its baseline and `descent + leading / 2` below; the line takes the maximum contribution on each side during the existing sequential scan. This avoids combining ascent from one run with leading from another and requires no extra pass.

Line height and line spacing are separate. Line height resolves the line box around its natural extents through `.natural`, `.multiple`, `.atLeast`, or `.exactly`; any difference is split equally above and below the natural box. Line spacing remains external space between adjacent line boxes and never changes the line's baseline-local content geometry. Render bounds remain independent and may extend outside either box.

Composition may speculatively position through the next opportunity, then truncate reusable position storage to the selected candidate without copying glyphs. Once workspace capacity stabilises, single-line composition performs no allocation. Positioned glyphs remain baseline-local so later vertical stacking needs only one document-space baseline per line; it does not rewrite glyph positions when line spacing changes.

Line composition is resumable. Full shaped-input validation happens once when creating an initial compact `LineStart`; each completed line returns the next source, glyph, run, break-opportunity, and line-break-unit indices. Subsequent lines continue directly from those indices without rescanning earlier text or reallocating the caller-owned line workspace.

Complete line layout repeatedly resumes until the source is exhausted; line limits are not an implicit engine constraint. Every positioned glyph appends to one contiguous position column and every `PositionedLine` appends to one contiguous line column in `LineLayoutWorkspace`. A line references its exact position range and records its document-space baseline while glyph positions remain baseline-local. Explicit line spacing advances subsequent line tops without altering any line's internal geometry.

Paragraph composition groups consecutive positioned lines at mandatory source breaks. `PositionedParagraph` is a compact derived record containing its consumed source range, line range, document-space bounds, optional render bounds, and first/last baselines. Paragraph records append to a third contiguous column in the existing `LineLayoutWorkspace`; they introduce no additional workspace and duplicate neither glyphs nor lines. Paragraph spacing is applied only between paragraphs, while line spacing remains only between lines within a paragraph.

The resolved line-box width follows visible typographic advance, not glyph render bounds. Trailing break whitespace belongs to the consumed line but is excluded from its visible advance, and glyph outlines may naturally overhang their advance cells. Wrapping and alignment therefore remain stable while independent render bounds retain the complete area needed for later clipping, culling, and invalidation.

Shaping workspaces are call-local noncopyable values initially. They own exact contiguous glyph and scratch buffers, grow geometrically when required, and release deterministically. Capacity is never exposed through the eventual public text API. A future document, layout session, or execution lane may retain and reuse the same workspace without changing algorithm inputs or public ownership.

Workspace vocabulary is stage-oriented and consistent. `ShapingWorkspace`, `LineBreakWorkspace`, and `LineLayoutWorkspace` each own the reusable typed columns required by one processing stage; their outputs remain valid until that workspace is reused. Line layout owns positioned-glyph, positioned-line, and positioned-paragraph columns. Leaf `Buffer` types each own one contiguous data-oriented column. `Storage` is reserved for long-lived retained identity such as `SFNT.FaceStorage`. Per-run shaping temporaries live in `ShapingScratch`, not another stage workspace.

Run shaping separates source and output records. `TextRun` describes one contiguous UTF-8 source range with a resolved face, size, direction, script, language, and indices into precompiled OpenType plans. `GlyphRun` identifies the corresponding range in one shared contiguous glyph buffer. Core execution borrows run and plan columns through call-local `Span` values; spans are never stored. Lookup-plan compilation remains outside the hot run executor.

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

## Deferred Content API Vocabulary

The future content API will use `Element` for a source-addressable document/content unit. `Paragraph` is the standard text element. A paragraph produces derived `Line` values, and each line references positioned glyph ranges from shared layout storage. Unlike TextKit 2's high-level API, these approachable abstractions must retain efficient direct access to contiguous glyph and range data rather than completely abstracting glyphs away. Words or Unicode line-break segments are temporary layout information, not elements. Other element kinds remain an open design question; attachments are not currently a requirement or commitment.
