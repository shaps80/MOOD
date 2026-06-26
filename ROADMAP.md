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

Can another platform run MOOD without a GameCore rewrite?

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

- [x] Define camera state in GameCore
- [x] Follow player within level bounds
- [x] Apply camera transform in platform renderers

Question answered:

Can MOOD present worlds larger than the viewport?

## Milestone 7 - Render Commands

Status: Done

- [x] Add platform-neutral render commands in GameCore
- [x] Add a RenderContext draw API for sprites, rect fills, and rect strokes
- [x] Keep stroke expansion platform-neutral
- [x] Make platform renderers consume render primitives
- [x] Share missing-texture color through GameCore

Question answered:

Can MOOD describe what to draw before each platform decides how to draw it?

## Milestone 8 - Visibility & Render Ordering

Status: In Progress

- [x] Render only visible tile range
- [x] Render only visible sprites/entities
- [x] Add render layer ordering
- [x] Keep deterministic draw order within each layer
- [x] Generalize entity render visibility so future enemies and pickups inherit culling without player-specific paths

Question answered:

Can MOOD keep render work bounded by what the player can see while preserving draw order?

## Milestone 9 - Render Batching

Status: Not Started

- [ ] Measure command, primitive, and draw-call counts after visibility culling
- [ ] Define batching rules that preserve layer and z-index ordering
- [ ] Batch compatible consecutive rect primitives
- [ ] Batch compatible consecutive sprite primitives by texture
- [ ] Keep platform-specific batching optimizations behind the same GameCore render command semantics

Question answered:

Can MOOD reduce draw calls without changing visual ordering or increasing platform rewrite cost?

## Milestone 10 - Collision Filtering & Interactions

Status: Not Started

- [ ] Add enemy entity
- [ ] Define collision layers and masks
- [ ] Keep player-vs-world collision blocking movement
- [ ] Support pickup overlap without blocking movement
- [ ] Support player/enemy interaction

Question answered:

Can MOOD distinguish blocking collisions from gameplay overlaps?

## Milestone 11 - Playable Game

Status: Not Started

- [ ] Complete playable game
- [ ] Published on itch.io

This is the most important milestone.

Everything before this is technology validation.

## Milestone 12 - Swift Tooling Review

Status: Not Started

- [ ] Review build, packaging, and deployment scripts
- [ ] Identify which workflows should move into Swift
- [ ] Consolidate useful tooling behind Swift entry points

Question answered:

Can MOOD's project tooling grow toward editor workflows?

## Backlog

Potential future improvements. These are not committed milestone work.

- Collision shapes beyond rectangles, such as ellipses or polygons, once gameplay needs them.
- Convenience APIs for adjusting rectangles in code, such as edge-specific padding/insetting.
- Rounded rectangles or arbitrary path drawing support, once UI or gameplay needs them.
- Define failure/death condition.
- Track active respawn point.
- Add checkpoint trigger.
- Respawn player at active checkpoint after failure.
