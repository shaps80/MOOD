# PixlText Context

## Scope

PixlText is one cross-platform Swift target. Current work is the low-level text core: Unicode, fonts, shaping, glyph positioning, lines, and paragraphs. High-level document/editing APIs and glyph imaging are later layers inside the same target.

The core is platform-independent and struct-first. It borrows `String` UTF-8/scalar views, uses explicit inputs, and writes into caller-owned reusable contiguous storage. Hot paths avoid hidden caches, dynamic dispatch, temporary collections, and steady-state allocation. Reference types require stable identity or mutable ownership.

## Fonts and Shaping

- `Font` is the public declarative value over an internal descriptor and process registry.
- `SFNT.*` is internal. Registration parses and retains font bytes once; hot measurement/shaping uses compact face identities.
- Implemented metrics/tables include Unicode cmap, horizontal metrics, TrueType render bounds, GSUB 1–8, GPOS 1–9, and required GDEF data.
- OpenType plans are flat immutable native-endian columns. Hot shaping uses indexed scans, binary search, read/write compaction, and reusable buffers.
- NFC normalization and Unicode Script use checked-in Unicode 16 tables. No Foundation/platform normalization.
- `TextRun` describes source/font/direction/script/language/plans. `GlyphRun` references output in one shared glyph buffer.
- Script-specific preprocessing, bidi, language policy, variable-font variations, Device adjustments, AAT, and Graphite remain later work.
- Embedded bitmap fonts are required eventually; bitmap-strike parsing/extraction is not implemented.

## Line and Paragraph Layout

- UAX #14 Unicode 16 line breaking writes sparse allowed/mandatory UTF-8 offsets. No-break controls are authoritative.
- Composition scans shaped clusters sequentially, never splits a cluster, and selects the last legal fitting opportunity. First unbreakable segments overflow intact.
- Consumed ranges include trailing break whitespace/control characters; visible ranges and advance exclude them.
- Typographic advance controls wrapping. Render bounds remain independent and may overhang.
- Mixed-run natural geometry takes maximum above/below contributions during the existing scan. `LineHeight` supports natural, multiple, minimum, and exact resolution.
- Glyph positions remain baseline-local. Each positioned line stores one document-space baseline and references shared position/glyph ranges.
- Composition borrows one `ParagraphStyle` per source paragraph. Alignment stores a horizontal line origin rather than rewriting every glyph position.
- Full composition continues until source exhaustion; line limits are explicit constraints, never an implicit cap.
- Mandatory breaks group lines into compact `PositionedParagraph` records containing source/line ranges, document bounds, render bounds, and first/last baselines.
- Paragraph records share `LineLayoutWorkspace`; they duplicate no glyph or line data. Line spacing applies within paragraphs; paragraph spacing applies between them.

## Storage Vocabulary

Exactly three stage workspaces exist: `ShapingWorkspace`, `LineBreakWorkspace`, and `LineLayoutWorkspace`. Outputs remain valid until reuse. A `Buffer` is one typed contiguous column. `Storage` is long-lived retained identity such as `SFNT.FaceStorage`. `ShapingScratch` holds per-run temporaries.

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
}

struct LineLimit {
    var minimum: UInt
    var maximum: UInt // zero means unlimited
}
```

Defaults: leading alignment, zero indentation/spacing, automatic hyphenation, unlimited lines, visible overflow. Leading/trailing follow resolved writing direction. Reserved minimum lines affect overall layout height without fabricating empty line records. Truncation/hyphen insertion must occur only at legal cluster boundaries.

First-line indentation applies inward from the aligned logical edge for leading and trailing alignment, and is ignored for centered text. Bidi resolution will later map those logical edges to physical left/right for each paragraph.

`ParagraphStyle`, `TextAlignment`, `Indentation`, `Spacing`, and `Hyphenation` now exist as value types. Alignment, indentation, and spacing affect composition. Automatic hyphen insertion remains future work; the value is already carried per paragraph.

## Future Content API

`Element` is a source-addressable content unit; `Paragraph` is the standard text element; `Line` is derived layout referencing positioned glyph ranges. These approachable values must retain direct efficient access to contiguous glyph/range data rather than hide glyphs like TextKit 2. Break segments are not elements. Attachments remain uncommitted.

Glyph imaging is separate from shaping/layout. Initial vector imaging is dynamic memory-only MSDF generation with separate generation and atlas-packing inputs/outputs. Shaping/layout never depends on atlas placement.
