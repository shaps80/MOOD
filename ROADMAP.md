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

Status: In Progress

- [x] Load PNG assets
- [ ] Load audio assets
- [x] Package assets correctly

Question answered:

Can MOOD load content?

## Milestone 4 - Sprites

Status: In Progress

- [x] Textured quads
- [ ] Sprite sheets
- [ ] Sprite animation

Question answered:

Can MOOD display game art?

## Milestone 5 - World

Status: Not Started

- [ ] Camera
- [ ] Collision
- [ ] Tile maps

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

## Notes To Revisit

### `Game.requiredSpriteAssets`

Current purpose:

* `GameCore` states which sprite assets the current game state may need, including stable sprite IDs and game-owned asset paths.
* Platform layers load those paths and cache platform-specific texture objects by sprite ID.
* This keeps image loading and WebGL texture objects out of `GameCore`, while keeping game content paths out of `PlatformWeb`.

This is intentionally simple right now. With one player, it mostly duplicates the current `sprites` list.

Before growing it, discuss whether asset requirements should come from:

* loaded scene or level data
* current camera or viewport visibility
* animation state
* preload/cache rules
* a future asset manifest

Do not let `requiredSpriteAssets` become accidental long-term asset architecture without revisiting this tradeoff.
