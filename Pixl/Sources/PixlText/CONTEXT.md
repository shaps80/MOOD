# PixlText Context

## Scope

PixlText is one cross-platform Swift target. Current work is the low-level text core: Unicode, fonts, shaping, glyph positioning, lines, and paragraphs. High-level document/editing APIs and glyph imaging are later layers inside the same target.

The core is platform-independent and struct-first. It borrows `String` UTF-8/scalar views, uses explicit inputs, and writes into caller-owned reusable contiguous storage. Hot paths avoid hidden caches, dynamic dispatch, temporary collections, and steady-state allocation. Reference types require stable identity or mutable ownership.

## Fonts and Shaping

- `Font` is the public declarative value over an internal descriptor and process registry.
- Layout requires one base font covering the entire source. Sparse range overrides describe mixed fonts; callers never need to manufacture complete font-run coverage. Empty source therefore still has deterministic font metrics.
- `SFNT.*` is internal. Registration parses and retains font bytes once; hot measurement/shaping uses compact face identities.
- Implemented metrics/tables include Unicode cmap, horizontal metrics, TrueType render bounds, GSUB 1–8, GPOS 1–9, and required GDEF data.
- OpenType plans are flat immutable native-endian columns. Hot shaping uses indexed scans, binary search, read/write compaction, and reusable buffers.
- Layout sessions flatten GSUB/GPOS topology once per face. Per-layout plans share those columns, select only script/language/coordinate-dependent execution lists, and resolve GPOS variation deltas only for rules that match actual glyphs.
- NFC normalization and Unicode Script use checked-in Unicode 16 tables. No Foundation/platform normalization.
- `TextRun` describes source/font/direction/script/language/plans. `GlyphRun` references output in one shared glyph buffer.
- Supported TrueType variable fonts expose `fvar` axes/named instances and resolve descriptor coordinates through `avar`. Semantic weight/italic modifiers select matching `wght`/`ital`/`slnt` axes unless explicitly overridden.
- Variable instances apply `gvar` interpolation to simple and composite outlines, HVAR/VVAR advance deltas, MVAR global metrics, GSUB/GPOS FeatureVariations, and GDEF/GPOS VariationIndex adjustments. San Francisco validates that extreme weights change both advances and geometry.
- Default-axis instances retain the static fast path. Non-default render bounds are resolved once while shaping and reused by composition/debug output. CFF/CFF2 outline imaging remains outside the currently supported TrueType outline path.
- Shaping resolves each final glyph advance once and reuses repeated-glyph render bounds within a run, avoiding duplicate HVAR and `gvar` work without retaining coordinate-dependent face caches.
- Script-specific preprocessing, bidi, language policy, AAT, and Graphite remain later work.
- Embedded bitmap fonts are required eventually; bitmap-strike parsing/extraction is not implemented.

## Line and Paragraph Layout

- UAX #14 Unicode 16 line breaking writes sparse allowed/mandatory UTF-8 offsets. No-break controls are authoritative.
- Automatic English hyphenation uses checked-in Knuth–Liang patterns and exceptions compiled into a flat immutable trie. Matching writes opportunities into reusable line-break buffers; it does not consult platform services or allocate temporary collections.
- Composition scans shaped clusters sequentially, never splits a cluster, and selects the last legal fitting opportunity. First unbreakable segments overflow intact.
- Consumed ranges include trailing break whitespace/control characters; visible ranges and advance exclude them.
- Typographic advance controls wrapping. Render bounds remain independent and may overhang.
- Mixed-run natural geometry takes maximum above/below contributions during the existing scan. `LineHeight` supports natural, multiple, minimum, and exact resolution.
- Glyph positions remain baseline-local. Each positioned line stores one document-space baseline and references shared position/glyph ranges.
- Composition borrows one `ParagraphStyle` per source paragraph. Alignment stores a horizontal line origin rather than rewriting every glyph position.
- Full composition continues until source exhaustion; line limits are explicit constraints, never an implicit cap.
- `LayoutConstraints` applies to the whole layout. A zero maximum line count is unlimited; a reached nonzero maximum returns overflow status while retaining valid visible line/paragraph records.
- Mandatory breaks group lines into compact `PositionedParagraph` records containing source/line ranges, document bounds, render bounds, and first/last baselines.
- Paragraph records share `LineLayoutWorkspace`; they duplicate no glyph or line data. Line spacing applies within paragraphs; paragraph spacing applies between them.

## Storage Vocabulary

Exactly three stage workspaces exist: `ShapingWorkspace`, `LineBreakWorkspace`, and `LineLayoutWorkspace`. Outputs remain valid until reuse. A `Buffer` is one typed contiguous column. `Storage` is long-lived retained identity such as `SFNT.FaceStorage`. `ShapingScratch` holds per-run temporaries.

The temporary Playground bridge retains those same three workspaces across adjustments and materializes only run, paragraph, and overall layout bounds. It does not scan installed fonts or expose glyph/word/line debug records.

## Performance Invariants

- The retained-session Playground workload is the interactive regression gate: three SF Pro paragraphs, mixed sizes/styles, a 520-point width, and repeated font or paragraph changes. Its Debug median must remain below one 16.667 ms frame. Accepted medians are approximately 8.5 ms for unchanged, alignment, and size changes and 12 ms for continuously changing `wght`; Release remains below 0.5 ms. Full methodology and reference results live in the repository `PERF.md`.
- These are hot retained-session measurements. Font-byte loading, first face registration, SwiftUI event handling, drawing, and presentation are separate costs and must not be folded into comparisons with this baseline.
- Never rebuild or re-sort complete GSUB/GPOS topology per layout or per run. Face/session-owned templates retain the flat columns; each layout selects only the small script/language/coordinate-dependent execution list. Equivalent runs share one selected plan.
- Never resolve every GPOS VariationIndex while selecting a variable instance. Preserve unresolved adjustments/anchors in the template and resolve only rules that match positioned glyphs.
- Resolve nominal advances only after substitution has produced final glyph IDs. Do not perform a speculative pre-substitution HVAR pass followed by another final pass.
- Repeated glyphs within one run must not repeat TrueType/`gvar` outline interpolation. The bounded parallel render-bounds columns in `ShapingScratch` are reusable per-run scratch, not a hidden process cache; keep their lookup bounded so high-diversity runs cannot become quadratic.
- Performance coverage must drive the same `Font.LayoutDebugSession` API used by the Playground, vary paragraph alignment/font size/variable weight, preserve output geometry checks, and retain the 16.667 ms median assertion. Synthetic OpenType-only benchmarks are supplementary, not a substitute for the complete layout gate.

## Paragraph Style

```swift
struct ParagraphStyle {
    var alignment: TextAlignment
    var indentation: Indentation
    var spacing: Spacing
    var hyphenation: Hyphenation
}

struct Indentation {
    var leading: Float
    var trailing: Float
    var firstLine: Float
}

struct Spacing {
    var lineSpacing: Float
    var paragraphBefore: Float
    var paragraphAfter: Float
}

struct LayoutConstraints {
    var width: Float
    var lines: LineLimit
    var overflow: Overflow
    var defaultLineMetrics: DefaultLineMetrics
}

struct LineLimit {
    var minimum: UInt
    var maximum: UInt // zero means unlimited
}
```

Defaults: leading alignment, zero indentation/spacing, automatic hyphenation, unlimited lines, visible overflow, and automatic default-line metrics. `DefaultLineMetrics.automatic` uses base-font metrics; `.inherited` uses the final laid-out line and falls back to the base font. Leading/trailing follow resolved writing direction. Minimum lines affect only overall geometry; they create no source, glyph, line, paragraph, or selection records. Empty source still has one insertion line using base-font metrics even when the minimum is zero. Initial truncation supports a trailing ellipsis only; head/middle remain future modes. Truncation and soft/automatic hyphenation shape generated insertion glyphs without mutating source or fabricating source/glyph ranges. Both occur only at cluster boundaries.

First-line indentation applies inward from the aligned logical edge for leading and trailing alignment, and is ignored for centered text. Bidi resolution will later map those logical edges to physical left/right for each paragraph.

`ParagraphStyle`, `TextAlignment`, `Indentation`, `Spacing`, and `Hyphenation` are value types. Alignment, indentation, spacing, and hyphenation affect composition. Automatic currently means the portable English fallback; explicit language selection comes with broader language policy.

## Future Content API

`Element` is a source-addressable content unit; `Paragraph` is the standard text element; `Line` is derived layout referencing positioned glyph ranges. These approachable values must retain direct efficient access to contiguous glyph/range data rather than hide glyphs like TextKit 2. Break segments are not elements. Attachments remain uncommitted.

Glyph imaging is separate from shaping/layout. Initial vector imaging is dynamic memory-only MSDF generation with separate generation and atlas-packing inputs/outputs. Shaping/layout never depends on atlas placement.
