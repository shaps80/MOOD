# ROADMAP

## Milestone 0 - Runtime

Status: Done

- [x] Swift compiles to Wasm
- [x] Runs in browser
- [x] Basic game loop executes

Question answered:

Can it run MOOD?

## Milestone 1 - Rendering

Status: Done

- [x] WebGL2 context
- [x] Clear screen
- [x] Draw rectangle
- [x] Rectangle moves
- [x] Deploy to itch.io

Question answered:

Can MOOD render and be distributed?

## Milestone 2 - Input

Status: Done

- [x] Keyboard support
- [x] Touch support
- [x] Controller support

Question answered:

Can MOOD interact?

## Milestone 3 - Assets

Status: Done

- [x] Load PNG assets
- [x] Load audio assets
- [x] Package assets correctly

Question answered:

Can MOOD load content?

## Milestone 4 - Sprites

Status: Done

- [x] Textured quads
- [x] Sprite sheets
- [x] Sprite animation

Question answered:

Can MOOD display game art?

## Milestone 4.5 - Native Debug Platform

Status: Done

- [x] PlatformMac target
- [x] MetalKit renderer
- [x] Native keyboard input
- [x] Native controller input
- [x] Native audio
- [x] Packaged game assets

Question answered:

Can another platform run MOOD without a Pixl rewrite?

## Milestone 5 - World

Status: Done

- [x] Basic tile map model
- [x] Render screen-sized boundary wall map
- [x] Basic player/tile AABB collision tested against boundary walls
- [x] Cross-wall collision test map
- [x] Level owns tilemap and spawn point
- [x] Reset player to level spawn
- [x] Player controller

World support establishes tile maps, collision, spawn placement, and player movement control. Camera behavior is tracked separately because it needs its own design pass.

Question answered:

Can MOOD support a playable environment?

## Milestone 6 - Camera

Status: Done

- [x] Define camera state in Pixl
- [x] Follow player within level bounds
- [x] Apply camera transform in platform renderers

Question answered:

Can MOOD present worlds larger than the viewport?

## Milestone 7 - Render Commands

Status: Done

- [x] Add platform-neutral render commands in Pixl
- [x] Add a RenderContext draw API for sprites and immediate shape/path drawing
- [x] Keep shape primitive expansion platform-neutral
- [x] Make platform renderers consume render primitives
- [x] Share missing-texture color through Pixl

Question answered:

Can MOOD describe what to draw before each platform decides how to draw it?

## Milestone 8 - Visibility & Render Ordering

Status: Done

- [x] Render only visible tile range
- [x] Render only visible sprites/entities
- [x] Add render layer ordering
- [x] Keep deterministic draw order within each layer
- [x] Generalize entity render visibility so future enemies and pickups inherit culling without player-specific paths

Question answered:

Can MOOD keep render work bounded by what the player can see while preserving draw order?

## Milestone 9 - Render Batching

Status: Done

- [x] Measure command, primitive, and draw-call counts after visibility culling
- [x] Define batching rules that preserve layer ordering
- [x] Batch compatible consecutive shape primitives
- [x] Batch compatible consecutive sprite primitives by texture
- [x] Keep platform-specific batching optimizations behind the same Pixl render command semantics

Question answered:

Can MOOD reduce draw calls without changing visual ordering or increasing platform rewrite cost?

## Milestone 9.5 - Shape Rendering

Status: Done

- [x] Add `Shape`, `Path`, and primitive shape types in Pixl
- [x] Add `Material.shape(...)` for retained sprite and tile visuals
- [x] Remove `Material.color` in favor of shape materials plus tint
- [x] Add `RenderStyle` for immediate shape/path debug drawing
- [x] Support rect, rounded rect, ellipse, circle, capsule, and single-segment paths
- [x] Support circular and continuous rounded corner styles
- [x] Support tint, opacity, and blend mode for textured sprites and shape materials
- [x] Lower supported shapes to SDF batches in WebGL2 and Metal

Question answered:

Can MOOD use simple dynamic shapes as first-class game visuals without bypassing sprite lifecycle, visibility, ordering, or platform portability?

## Milestone 10 - Collision Filtering & Interactions

Status: Done

- [x] Define collision layers and masks
- [x] Support pickup overlap without blocking movement
- [x] Add contact phases for began, changed, and ended
- [x] Route collision callbacks to source entity owners

Question answered:

Can MOOD distinguish blocking collisions from gameplay overlaps?

## Milestone 10.5 - Entities and Testing

Status: In Progress

- [x] Add a game-facing Entity protocol
- [x] Split runtime entity state from entity behavior
- [x] Route update, collision, and sprite rendering through unified entity records
- [x] Keep level/tile geometry separate from entity lifecycle
- [x] Rename GameCore to Pixl
- [x] Move MOOD-specific entities, levels, IDs, and layers into the MOOD target
- [x] Let MOOD construct Pixl.Game from level, camera, and entity spawn data
- [ ] Camera anchor animates between 2 entities

Question answered:

Can MOOD add a new game entity without adding new per-type game loop paths?

## Milestone 11 - Swift Tooling Review

Status: Not Started

- [ ] Review build, packaging, and deployment scripts
- [ ] Identify which workflows should move into Swift
- [ ] Consolidate useful tooling behind Swift entry points

Question answered:

Can MOOD's project tooling grow toward editor workflows?

## Backlog

Potential future improvements. These are not committed milestone work.

- Collision shapes beyond rectangles, such as ellipses or polygons, once gameplay needs them.
- General arbitrary path drawing beyond the current primitive subset.
