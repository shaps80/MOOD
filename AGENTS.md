MOOD

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

2. Can It Run MOOD?

The inspiration is Doom.

Not because of its renderer.

Because of its portability.

The guiding question becomes:

Can it run MOOD?

rather than:

How much of MOOD needs to be rewritten?

A new platform should require a new adapter, not a new game.

The preferred approach is:

GameCore
+
Platform Layer
=
Playable Game

Examples:

GameCore + PlatformWeb      → Browser / itch.io
GameCore + PlatformIOS      → iPhone / iPad
GameCore + PlatformMacOS    → macOS
GameCore + PlatformWindows  → Windows
GameCore + PlatformLinux    → Linux / Steam Deck

Future ports should primarily involve implementing platform services:

* Rendering
* Input
* Audio
* Asset loading
* Platform lifecycle

The game itself should remain largely unchanged.

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

Use:

* `swiftly use 6.3.2`
* `./build.sh`
* `./build.sh -c release`
* `swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm`
* `swiftly run swift run --swift-sdk swift-6.3.2-RELEASE_wasm`
* `swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn`

Do not assume plain `swift` is the right compiler in agent shells.

On this machine, plain `swift` may resolve to `/usr/bin/swift` and use Xcode's Apple Swift frontend. That can fail or crash for the Wasm SDK with errors like:

* `No available targets are compatible with triple "wasm32-unknown-wasip1"`

For browser/Wasm builds, always invoke Swift through `swiftly run`.

`swiftly run swift run --swift-sdk swift-6.3.2-RELEASE_wasm` is useful as a Wasm build smoke check. Once `PlatformWeb` imports JavaScriptKit, browser execution should go through PackageToJS and `App/index.html`, because the app needs JavaScriptKit's browser runtime imports.

For local browser runs, prefer the repo script:

* `./build.sh`
* `./build.sh -c release`

Agents and humans should use this same script so changes to build flags, port, PackageToJS options, and printed URL stay in one place. The script serves on port `9999` and prints:

* `http://127.0.0.1:9999/App/index.html`
* the selected configuration

For browser packaging, use JavaScriptKit's PackageToJS SwiftPM plugin:

* `swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn`

This generates the JS/Wasm browser package under:

* `.build/plugins/PackageToJS/outputs/Package/`

The development browser page is:

* `App/index.html`

Serve the repository root locally, then open `/App/index.html`. The page imports:

* `../.build/plugins/PackageToJS/outputs/Package/index.js`

Useful checks:

* `swiftly run swift --version`
* `swiftly run swift build --scratch-path .build/host --target GameCore`
* `swiftly run swift test --scratch-path .build/host`
* `swiftly run swift build --swift-sdk swift-6.3.2-RELEASE_wasm`
* `swiftly run swift run --swift-sdk swift-6.3.2-RELEASE_wasm`
* `swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn`

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

GameCore

GameCore contains:

* Game rules
* World state
* Entities
* Collision
* Animation state
* AI
* Save data
* Gameplay systems

GameCore must remain platform-independent.

Critical Rules

GameCore must compile without importing:

* JavaScriptKit
* DOM APIs
* WebGL
* Metal
* UIKit
* AppKit
* WinUI
* Platform-specific frameworks

GameCore must compile on macOS using a normal Swift toolchain without SwiftWasm installed.

If gameplay code requires browser APIs, rendering APIs, or platform frameworks, it probably belongs somewhere else.

This is the single most important architectural constraint in the project.

GameCore also owns game-facing render state and decisions.

Examples that belong in GameCore:

* Which color should be shown
* Which sprite or animation frame is active
* Entity positions
* Camera state
* World/tile state
* Collision and gameplay timing decisions

Examples that do not belong in GameCore:

* WebGL calls
* Canvas lookup and sizing
* Browser time APIs
* DOM events
* JavaScriptKit interop

Platform layers may provide external facts such as elapsed time, input state, asset bytes, or viewport size. GameCore decides what the game state becomes from those facts.

⸻

PlatformWeb

Responsible for:

* WebGL2
* Browser lifecycle
* Browser input
* Browser audio
* Asset loading
* Browser-specific services

Its job is to run GameCore.

Nothing more.

PlatformWeb must not own game rules, demo behavior, visual selection logic, or gameplay state just because the first visible output is rendered in a browser.

If PlatformWeb needs to render something, prefer this flow:

* PlatformWeb reads browser/platform facts.
* PlatformWeb passes those facts into GameCore.
* GameCore updates and exposes platform-neutral state.
* PlatformWeb translates that state into WebGL/DOM/audio calls.

PlatformWeb is specifically the browser/Wasm adapter.

It is allowed to depend on Wasm/browser-only packages such as JavaScriptKit.

Do not require PlatformWeb, MOOD, or the whole package to build in Xcode or with the default macOS host toolchain.

The required validation split is:

* GameCore must build on host: `swiftly run swift build --scratch-path .build/host --target GameCore`
* GameCore tests must pass on host: `swiftly run swift test --scratch-path .build/host`
* Browser app must build/package through Wasm: `swiftly run swift package --swift-sdk swift-6.3.2-RELEASE_wasm js --product MOOD --use-cdn`

Avoid adding `#if os(WASI)` fallbacks to PlatformWeb solely to make Xcode or default host builds happy. Add conditionals only when they serve a real platform adapter need.

⸻

Future Platform Layers

Potential future implementations:

* PlatformIOS
* PlatformMacOS
* PlatformWindows
* PlatformLinux

All should be capable of running the same GameCore.

⸻

Repository Structure

Initial structure:

MOOD/
├── App/
├── GameCore/
└── PlatformWeb/
└── MOOD/

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

and then be able to run the existing GameCore.

The question should always be:

Can it run MOOD?

⸻

Definition of Success

A player can open a browser, launch MOOD, and play a complete game built primarily to learn game development rather than engine development.

If future opportunities emerge naturally:

* Framework
* Tooling
* Asset pipeline
* Additional platforms

they are welcome.

But they are optional.

The game is not optional.
