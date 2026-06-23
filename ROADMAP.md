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

World support establishes tile maps, collision, spawn placement, and player movement control. Respawn/checkpoint and camera behavior are tracked separately because they need their own design passes.

Question answered:

Can MOOD support a playable environment?

## Milestone 6 - Respawn

Status: In Progress

- [ ] Define failure/death condition
- [ ] Track active respawn point
- [ ] Add checkpoint trigger
- [ ] Respawn player at active checkpoint after failure

Question answered:

Can MOOD recover the player after failure?

## Milestone 7 - Camera

Status: Not Started

- [ ] Define camera state in GameCore
- [ ] Follow player within level bounds
- [ ] Apply camera transform in platform renderers

Question answered:

Can MOOD present worlds larger than the viewport?

## Milestone 8 - Visibility & Render Ordering

Status: Not Started

- [ ] Render only visible tile range
- [ ] Render only visible sprites/entities
- [ ] Add render layer / z-index ordering
- [ ] Keep deterministic draw order within each layer

Question answered:

Can MOOD keep rendering work bounded by what the player can see?

## Milestone 9 - Collision Filtering & Interactions

Status: Not Started

- [ ] Add enemy entity
- [ ] Add pickup entity
- [ ] Define collision layers and masks
- [ ] Keep player-vs-world collision blocking movement
- [ ] Support pickup overlap without blocking movement
- [ ] Support player/enemy interaction

Question answered:

Can MOOD distinguish blocking collisions from gameplay overlaps?

## Milestone 10 - Playable Game

Status: Not Started

- [ ] Complete playable game
- [ ] Published on itch.io

This is the most important milestone.

Everything before this is technology validation.

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
- Convenience APIs for adjusting rectangles in code, such as edge-specific padding/insetting.
