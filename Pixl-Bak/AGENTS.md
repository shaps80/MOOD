Pixl

A small native-first Swift 2D game engine with multiple executable targets for games and experiments, while preserving browser and future platform portability.

⸻

Purpose

The primary goal is to learn game and engine development as quickly as possible by leveraging existing expertise in:

* Swift
* SwiftPM
* Architecture
* Tooling
* Apple platform development

Pixl is now the engine target.

The executable targets are games or experiments built on Pixl.

The engine exists to serve those games and experiments. Any framework, tooling, editor, asset pipeline, or runtime abstractions must emerge from real executable-target needs, not speculative engine design.

⸻

Core Principles

1. Game First

Success is:

* Playable game or experiment executable targets
* Running natively first
* Wasm continues to compile for both Pixl engine code and game executable targets at all times
* Deployable to itch.io when explicitly packaged
* Learnings about game and engine development

Failure is:

* Building engine infrastructure without improving or shipping a playable target

Playable targets are the primary proof that Pixl is useful.

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

The game executable itself should remain largely unchanged when adding a new platform adapter.

When behavior can live in Pixl without depending on platform APIs, prefer doing it there so every platform has less to decide, duplicate, or port.

Examples include game-facing render command expansion, visibility decisions, ordering rules, and other platform-neutral semantics.

Platforms may still diverge when a backend can provide a meaningfully better implementation for performance or platform capability reasons.

⸻

3. Architecture Is a Constraint, Not a Goal

Architecture exists to preserve future opportunities.

Architecture is not the product by itself.

Pixl is the engine, but playable game and experiment targets remain the proof of value.

Avoid building systems that are not currently required by at least one executable target.

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

Keep the engine and games simple, but treat performance problems in core loops as design problems, not cleanup tasks for later.

⸻

6. Discuss Before Editing

Unless the user explicitly says to implement it, fix it, make the change, or otherwise clearly asks for code edits, treat milestone, design, architecture, and gameplay requests as discussion first.

Propose the approach, wait for alignment, then edit.

⸻

Target Platforms

Initial Target

* Native host platform first
* macOS on this machine

On-Request Targets

* Browser
* itch.io
* Mobile

Future Possibilities

* iOS
* Windows
* Linux
* Steam Deck
* Other experimental targets

The default development and verification loop is native-first.

Browser/Wasm and mobile are portability/distribution targets. Check them when explicitly requested, when touching their platform layer, or when a change is intended to affect those platforms.

⸻

Rendering Strategy

Current Direction

Native/default:

* Swift
* PlatformMac on this machine
* Metal for macOS rendering

Browser/on-request:

* SwiftWasm
* JavaScriptKit (or successor browser interop layer)
* WebGL2

Toolchain Notes

This project uses Swiftly-managed Swift toolchains.

Agent verification preference:

* Use the repo scripts in `./.scripts/` for Wasm checks so Swiftly, Wasm SDK selection, and cache behavior stay in one place.
* Default verification is native-first: use normal SwiftPM host builds through Swiftly on the current machine. On macOS, use `swiftly run swift build --scratch-path .build/host --target Pixl` or `swiftly run swift build --scratch-path .build/host --target Invaders`. On Windows, use the equivalent SwiftPM host build for that Windows environment instead of a macOS-specific command.
* For engine-only Pixl changes, the normal native host build is usually enough unless the user asks for Wasm/mobile checks or the change touches platform-sensitive code.
* For browser/Wasm compile checks, use `./.scripts/build`. With no target argument, this compiles only the platform-agnostic `Pixl` target for Wasm in release mode and does not create `.dist/` or a zip.
* For game Wasm compile checks, pass the executable target explicitly, for example `./.scripts/build Invaders`. Agents may safely run `./.scripts/build <Target>` when Wasm verification is requested or relevant. `build` only compiles; it does not generate browser files, `.dist/`, or an itch.io zip.
* For deploy/itch packaging, pass the executable target explicitly, for example `./.scripts/deploy Invaders`.
* For explicit local browser runs, use `./.scripts/serve Invaders`. This builds browser files into `.dist/` and serves them on port `9999`, but does not create an itch.io zip. Only run it when browser serving is explicitly requested.
* Do not launch browsers, start local browser testing flows, use browser automation, run `./.scripts/serve`, or run test suites unless explicitly requested.
* The user handles gameplay, browser, and test-suite verification unless explicitly requested.
Install the browser packaging tools:

* `brew install binaryen`

`binaryen` provides `wasm-opt`. PackageToJS uses it automatically for release packaging when it is available on `PATH`. Without it the build still works, but the `.wasm` output is larger.

Use:

* `swiftly use 6.3.2`
* `./.scripts/build`
* `./.scripts/build Invaders`
* `./.scripts/deploy Invaders`
* `./.scripts/serve Invaders`
* `swiftly run swift build --scratch-path .build/host --target Pixl`
* `swiftly run swift build --scratch-path .build/host --target Invaders`

Do not assume plain `swift` is the right compiler in agent shells.

On this machine, plain `swift` may resolve to `/usr/bin/swift` and use Xcode's Apple Swift frontend. That can fail or crash for the Wasm SDK with errors like:

* `No available targets are compatible with triple "wasm32-unknown-wasip1"`

For browser/Wasm builds, always invoke Swift through `swiftly run` or the repo scripts in `./.scripts/`.

For explicit local browser runs, prefer the repo script:

* `./.scripts/serve Invaders`

Humans and explicitly browser-running agents should use this same script so changes to build flags, port, PackageToJS options, and printed URL stay in one place. The script builds `.dist/`, serves it on port `9999`, and prints:

* `http://127.0.0.1:9999/`
* the selected product
* the selected configuration

For itch.io packaging, prefer:

* `./.scripts/deploy Invaders`

This creates:

* `.dist/index.html`
* `.dist/pixl.js`
* `.dist/<Product>.wasm`
* `<Product>.zip`

Upload `<Product>.zip` to itch.io. The zip has `index.html` at the root and contains the JS/Wasm files locally, without CDN imports.

`deploy` intentionally does the boring packaging path first: PackageToJS without `--use-cdn`, npm install for the generated package dependencies, bundle to one browser module, copy the Wasm file, generate `index.html`, then zip `.dist/`.

Useful checks:

* `swiftly run swift --version`
* `swiftly run swift build --scratch-path .build/host --target Pixl` for native host Pixl checks on macOS
* `swiftly run swift build --scratch-path .build/host --target Invaders` for native host game checks on macOS
* `./.scripts/build` for engine-only Pixl Wasm compile checks
* `./.scripts/build Invaders` for game Wasm compile checks
* `./.scripts/serve Invaders` only for explicit browser-serving checks

For changes that should keep every active platform compiling, run a native host build for the affected target on the current OS first. Add Wasm (`./.scripts/build <Target>`) or mobile checks only when explicitly requested, when touching that platform layer, or when the change is meant to affect that platform.

Prefer dedicated scratch paths for direct SwiftPM host checks. Reusing the default `.build` for both host tests and Wasm PackageToJS builds can leave SwiftPM with stale cross-target build graph entries.

Explicit Non-Goals

At this stage:

* WebGPU evaluation
* Custom engine architecture for its own sake
* ECS architecture
* Advanced rendering systems
* Editor development
* Toolchain development

Those may be explored later if justified by playable targets.

⸻

Architectural Structure

Pixl

Pixl is the platform-independent engine target.

Pixl contains shared engine/runtime concepts such as:

* Game container and loop-facing state
* World, scene, entity, and component-style data structures
* Collision and contact systems
* Animation and sprite state
* Input abstractions
* Camera and viewport state
* Game-facing render planning and render commands
* Asset metadata such as sprite and sound descriptors

Concrete game rules, specific entities, levels, game config, and experiment behavior belong in executable targets such as `Sandbox` and `Invaders` unless they have proven reusable across targets.

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

If engine or gameplay code requires browser APIs, rendering APIs, or platform frameworks, it probably belongs in a platform adapter or executable target instead.

This is the single most important architectural constraint in the project.

Pixl owns platform-neutral, game-facing render state and decisions.

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

Platform layers may provide external facts such as elapsed time, input state, asset bytes, or viewport size. Pixl and the active executable target decide what the game state becomes from those facts.

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

PlatformWeb must not own game rules, demo behavior, visual selection logic, or gameplay state just because a visible output is rendered in a browser.

If PlatformWeb needs to render something, prefer this flow:

* PlatformWeb reads browser/platform facts.
* PlatformWeb passes those facts into Pixl.
* Pixl updates and exposes platform-neutral state.
* PlatformWeb translates that state into WebGL/DOM/audio calls.

PlatformWeb is specifically the browser/Wasm adapter.

It is allowed to depend on Wasm/browser-only packages such as JavaScriptKit.

Do not require PlatformWeb or the whole browser adapter to build in Xcode or with the default macOS host toolchain. Pixl itself must remain host-buildable.

The required validation split is:

* Pixl must build on the native host toolchain: on macOS, `swiftly run swift build --scratch-path .build/host --target Pixl`; on Windows, use the equivalent SwiftPM host build for Windows.
* Native game targets should build with normal SwiftPM host builds on the current machine. On this Mac, use `swiftly run swift build --scratch-path .build/host --target Invaders`.
* Browser game targets build through Wasm with an explicit target, for example `./.scripts/build Invaders`, but this is on-request unless browser code changed or the change is meant to affect Web.
* Mobile checks are on-request unless mobile platform code changed or the change is meant to affect mobile.
* Test suites are user-run unless explicitly requested.

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

Current structure:

Pixl/
├── Sources/Pixl/              # platform-independent engine
├── Sources/PlatformMac/       # macOS native adapter
├── Sources/PlatformWeb/       # browser/Wasm adapter
├── Sources/Sandbox/           # game/experiment executable target
├── Sources/Invaders/          # game executable target
├── Sources/... other targets   # future games or experiments
├── .scripts/                  # build, serve, deploy helpers
└── docs/                      # roadmap and project docs

Executable targets own their resources in `Sources/<Target>/Resources/assets` and declare them in `Package.swift`. Shared or legacy top-level asset folders should not be treated as the active source of truth unless the manifest says so.

This structure exists to reinforce separation between engine, games/experiments, and platform adapters.

⸻

Roadmap

Roadmap goals, milestone status, and progress live in:

* `docs/ROADMAP.md`

AGENTS.md should contain durable operating rules only. Do not duplicate roadmap progress here.

⸻

Potential Emergent Opportunities

These are opportunities.

They are not goals.

⸻

Engine Surface

Pixl may grow a small reusable Swift game-engine surface as executable targets demonstrate real needs.

Possible examples:

* Texture
* Sprite
* Audio
* Input
* TileMap
* Camera

Comparable scope:

* raylib
* SDL

Not comparable scope:

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

A player can launch a native executable target built on Pixl and play a complete game or meaningful experiment. Browser/itch.io and mobile distribution remain important portability paths, but they are on-request checks rather than the default development loop. The engine is successful when it helps ship playable targets.

If future opportunities emerge naturally:

* Engine surface
* Tooling
* Asset pipeline
* Additional platforms

they are welcome.

But they are optional.

Playable targets are not optional.
