Pixl

A small retro 2D game built in Swift, targeting the browser first, while preserving the ability to port to native platforms later.

⸻

Purpose

The primary goal is to learn game development as quickly as possible by leveraging existing expertise in:

* Swift
* SwiftPM
* Architecture
* Tooling
* Apple platform development

This project is not an engine project.

The game comes first.

Any framework, tooling, editor, asset pipeline, or runtime abstractions must emerge from the needs of the game itself.

⸻

Core Principles

1. Game First

Success is:

* A playable game
* Running in the browser
* Deployable to itch.io
* Learnings about game development

Failure is:

* Building infrastructure without shipping a game

The game is always the primary artifact.

⸻

2. Can It Run on Pixl?

The inspiration is Doom.

Not because of its renderer.

Because of its portability.

The guiding question becomes:

Can it run on Pixl?

rather than:

How much of Pixl needs to be rewritten?

A new platform should require a new adapter, not a new game.

The preferred approach is:

Pixl
+
Platform Layer
=
Playable Game

Examples:

Pixl + PlatformWeb      → Browser / itch.io
Pixl + PlatformIOS      → iPhone / iPad
Pixl + PlatformMacOS    → macOS
Pixl + PlatformWindows  → Windows
Pixl + PlatformLinux    → Linux / Steam Deck

Future ports should primarily involve implementing platform services:

* Rendering
* Input
* Audio
* Asset loading
* Platform lifecycle

The game itself should remain largely unchanged.

When behavior can live in Pixl without depending on platform APIs, prefer doing it there so every platform has less to decide, duplicate, or port.

Examples include game-facing render command expansion, visibility decisions, ordering rules, and other platform-neutral semantics.

Platforms may still diverge when a backend can provide a meaningfully better implementation for performance or platform capability reasons.

⸻

3. Architecture Is a Constraint, Not a Goal

Architecture exists to preserve future opportunities.

Architecture is not the product.

The game remains the product.

We will avoid building systems that are not currently required by the game.

⸻

4. Extract On Second Occurrence

Rule:

* First occurrence → implement directly
* Second occurrence → extract abstraction

Avoid speculative framework design.

Avoid building infrastructure before real requirements emerge.

Abstractions should be justified by demonstrated repetition, not anticipated future needs.

⸻

5. Performance Is A Design Constraint

This is game development.

Performance at every level is priority.

Do not bake avoidable O(n), allocation churn, redundant work, or hidden per-frame cost into the game's models, APIs, update loops, rendering paths, asset paths, or future engine-like code.

Prefer simple data shapes that make hot paths O(1), cacheable, precomputed, or directly indexable.

Keep the code game-first and simple, but treat performance problems in core loops as design problems, not cleanup tasks for later.

⸻

6. Discuss Before Editing

Unless the user explicitly says to implement it, fix it, make the change, or otherwise clearly asks for code edits, treat milestone, design, architecture, and gameplay requests as discussion first.

Propose the approach, wait for alignment, then edit.

⸻

Target Platforms

Initial Target

* Browser
* itch.io

Future Possibilities

* iOS
* macOS
* Windows
* Linux
* Steam Deck
* Other experimental targets

The browser is the first platform.

It is not necessarily the final platform.

⸻

Rendering Strategy

Current Direction

* Swift
* SwiftWasm
* JavaScriptKit (or successor browser interop layer)
* WebGL2

Toolchain Notes

This project uses Swiftly-managed Swift toolchains.

Agent verification preference:

* Default to direct SwiftPM build checks through `swiftly run`.
* When starting or verifying agent work, do not run `./build.sh` by default because it also starts the browser-serving flow.
* For Pixl/gameplay changes, run `swiftly run swift build --scratch-path .build/host --target Pixl`.
* For browser/Wasm compile checks, run `swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm`.
* Do not run `./deploy-wasm.sh` for routine verification; reserve it for explicit deploy/itch packaging requests or when the user says they are running that flow themselves.
* Do not launch browsers, start local browser testing flows, use browser automation, or run test suites unless explicitly requested.
* The user handles gameplay, browser, and test-suite verification.
Install the browser packaging tools:

* `brew install binaryen`

`binaryen` provides `wasm-opt`. PackageToJS uses it automatically for release packaging when it is available on `PATH`. Without it the build still works, but the `.wasm` output is larger.

Use:

* `swiftly use 6.3.2`
* `./build.sh`
* `./build.sh -c release`
* `./deploy-wasm.sh`
* `./deploy-wasm.sh -c release`
* `swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm`
* `swiftly run swift run --swift-sdk swift-6.3.2-RELEASE_wasm`

Do not assume plain `swift` is the right compiler in agent shells.

On this machine, plain `swift` may resolve to `/usr/bin/swift` and use Xcode's Apple Swift frontend. That can fail or crash for the Wasm SDK with errors like:

* `No available targets are compatible with triple "wasm32-unknown-wasip1"`

For browser/Wasm builds, always invoke Swift through `swiftly run`.

`swiftly run swift run --swift-sdk swift-6.3.2-RELEASE_wasm` is useful as a Wasm build smoke check. Once `PlatformWeb` imports JavaScriptKit, browser execution should go through PackageToJS and the generated `dist/index.html`, because the app needs JavaScriptKit's browser runtime imports.

For explicit local browser runs, prefer the repo script:

* `./build.sh`
* `./build.sh -c release`

Humans and explicitly browser-running agents should use this same script so changes to build flags, port, PackageToJS options, and printed URL stay in one place. The script builds the same `dist/` folder used for itch.io, serves it on port `9999`, and prints:

* `http://127.0.0.1:9999/`
* the selected configuration

For itch.io packaging, prefer:

* `./deploy-wasm.sh -c release`

This creates:

* `dist/index.html`
* `dist/pixl.js`
* `dist/pixl.wasm`
* `Pixl.zip`

Upload `Pixl.zip` to itch.io. The zip has `index.html` at the root and contains the JS/Wasm files locally, without CDN imports.

`deploy-wasm.sh` intentionally does the boring packaging path first: PackageToJS without `--use-cdn`, npm install for the generated package dependencies, bundle to one browser module, copy the Wasm file, generate `index.html`, then zip `dist/`.

Useful checks:

* `swiftly run swift --version`
* `swiftly run swift build --scratch-path .build/host --target Pixl`
* `swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm`
* `./build.sh` only for explicit browser-serving checks

Prefer the `.build/host` scratch path for host checks. Reusing the default `.build` for both host tests and Wasm PackageToJS builds can leave SwiftPM with stale cross-target build graph entries.

Explicit Non-Goals

At this stage:

* WebGPU evaluation
* Custom engine architecture
* ECS architecture
* Advanced rendering systems
* Editor development
* Toolchain development

Those may be explored later if justified by the game.

⸻

Architectural Structure

Pixl

Pixl contains:

* Game rules
* World state
* Entities
* Collision
* Animation state
* AI
* Save data
* Gameplay systems

Pixl must remain platform-independent.

Critical Rules

Pixl must compile without importing:

* JavaScriptKit
* DOM APIs
* WebGL
* Metal
* UIKit
* AppKit
* WinUI
* Platform-specific frameworks

Pixl must compile on macOS using a normal Swift toolchain without SwiftWasm installed.

If gameplay code requires browser APIs, rendering APIs, or platform frameworks, it probably belongs somewhere else.

This is the single most important architectural constraint in the project.

Pixl also owns game-facing render state and decisions.

Examples that belong in Pixl:

* Which color should be shown
* Which sprite or animation frame is active
* Entity positions
* Camera state
* World/tile state
* Collision and gameplay timing decisions

Examples that do not belong in Pixl:

* WebGL calls
* Canvas lookup and sizing
* Browser time APIs
* DOM events
* JavaScriptKit interop

Platform layers may provide external facts such as elapsed time, input state, asset bytes, or viewport size. Pixl decides what the game state becomes from those facts.

⸻

PlatformWeb

Responsible for:

* WebGL2
* Browser lifecycle
* Browser input
* Browser audio
* Asset loading
* Browser-specific services

Its job is to run Pixl.

Nothing more.

PlatformWeb must not own game rules, demo behavior, visual selection logic, or gameplay state just because the first visible output is rendered in a browser.

If PlatformWeb needs to render something, prefer this flow:

* PlatformWeb reads browser/platform facts.
* PlatformWeb passes those facts into Pixl.
* Pixl updates and exposes platform-neutral state.
* PlatformWeb translates that state into WebGL/DOM/audio calls.

PlatformWeb is specifically the browser/Wasm adapter.

It is allowed to depend on Wasm/browser-only packages such as JavaScriptKit.

Do not require PlatformWeb, Pixl, or the whole package to build in Xcode or with the default macOS host toolchain.

The required validation split is:

* Pixl must build on host: `swiftly run swift build --scratch-path .build/host --target Pixl`
* Test suites are user-run unless explicitly requested.
* Browser app must build through Wasm: `./build.sh`

Avoid adding `#if os(WASI)` fallbacks to PlatformWeb solely to make Xcode or default host builds happy. Add conditionals only when they serve a real platform adapter need.

⸻

Future Platform Layers

Potential future implementations:

* PlatformIOS
* PlatformMacOS
* PlatformWindows
* PlatformLinux

All should be capable of running the same Pixl.

⸻

Repository Structure

Initial structure:

Pixl/
├── Game/
├── Sources/Pixl/
├── Sources/PlatformWeb/
└── Sources/Sandbox/
└── Sources/Invaders/
└── Sources/... other games

This structure exists to reinforce separation between gameplay and platform concerns.

⸻

Roadmap

Roadmap goals, milestone status, and progress live in:

* `ROADMAP.md`

AGENTS.md should contain durable operating rules only. Do not duplicate roadmap progress here.

⸻

Potential Emergent Opportunities

These are opportunities.

They are not goals.

⸻

Framework

A small reusable Swift game framework.

Possible examples:

* Texture
* Sprite
* Audio
* Input
* TileMap
* Camera

Comparable to:

* raylib
* SDL

Not comparable to:

* Unity
* Unreal

⸻

Asset Pipeline

Possible examples:

* Sprite atlas generation
* Asset validation
* Build-time processing
* SwiftPM plugins

⸻

Tooling

Possible examples:

* Tile map tools
* Asset browsers
* Importers
* Content pipelines

⸻

Code-Driven Workflows

Potential future direction:

@SpriteAtlas("player")
enum PlayerSprites {
    case idle
    case run
    case jump
}

Swift macros, plugins, and code generation may enable workflows that traditionally require custom editors.

Only pursue this if real pain points emerge.

⸻

Hot Reloading

Potential future direction.

Not a goal.

Not a requirement.

Only pursue if it provides clear iteration speed improvements for game development.

⸻

Long-Term Vision

The inspiration is Doom.

Not because of its renderer.

Because of its portability.

The long-term goal is that new platforms require new adapters rather than game rewrites.

A future platform should only need to provide:

* Rendering
* Input
* Audio
* Asset loading
* Lifecycle services

and then be able to run the existing Pixl.

The question should always be:

Can it run on Pixl?

⸻

Definition of Success

A player can open a browser, launch Pixl, and play a complete game built primarily to learn game development rather than engine development.

If future opportunities emerge naturally:

* Framework
* Tooling
* Asset pipeline
* Additional platforms

they are welcome.

But they are optional.

The game is not optional.
