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

Status: In Progress

- [x] Basic tile map model
- [x] Render screen-sized boundary wall map
- [x] Basic player/tile AABB collision tested against boundary walls
- [ ] Cross-wall collision test map
- [ ] Spawn points and checkpoint respawn
- [ ] Camera

World support includes simple GameCore-controlled relocation for cases like falling, death, respawn, and checkpoint reset. This is not a generalized teleport or portal system unless the game needs one.

Question answered:

Can MOOD support a playable environment?

## Milestone 6 - Playable Game

Status: Not Started

- [ ] Complete playable game
- [ ] Published on itch.io

This is the most important milestone.

Everything before this is technology validation.

## Milestone 7 - Swift Tooling Review

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
