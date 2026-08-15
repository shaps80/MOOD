# PixlParticles Context

## Scope

`PixlParticles` is a platform-agnostic particle-system design. `PixlParticlesUI` is its Apple-platform editor for iOS, macOS, and visionOS. These documents cover both projects independently of Pixl's root project documents.

## Goals

- Keep particles and editor scene framing 3D.
- Offer expressive, composable Swift authoring types, then lower them into a runtime representation suitable for hot loops and GPU execution.
- Support CPU and GPU compute without guaranteeing the preferred backend when capabilities require fallback.
- Decide post-processing ownership explicitly, including bloom behavior across multiple or nested systems.

## Foundational Constraints

- Treat a particle effect as a deterministic program over time, not merely mutable emitters updated each frame. It must support pausing, seeking, scrubbing, repeatable tests, and precise state inspection.
- Support Niagara-style events as a core system capability, allowing causal communication between emitters through explicit triggers and event payloads.

## Evidence

- A dedicated particle renderer using direct buffer writes increased observed capacity from roughly 100,000 to 200,000 particles at 60 fps.
- GPU compute mattered around 100,000 particles, while smaller systems could favor CPU cost and memory usage.
- Earlier value APIs combining constants, ranges, random selection, interpolation, and easing became complex while remaining limiting.
- Renderer-global bloom threshold and soft-knee settings prevented systems from expressing different behavior.

## Boundaries

- `PixlParticles` declares no Apple platform minimum and must remain usable on non-Apple platforms.
- `PixlParticlesUI` imports `PixlParticles` and supports iOS, macOS, and visionOS.
- Rendering and simulation compute are separate concerns. A compute preference does not change GPU-backed rendering where applicable.
- Pixl renderer improvements may be identified, but particle-system design must not change Pixl implicitly.
- Tests use Swift Testing. XCTest is reserved for performance tests. UI testing is manual only.
- Never run the app; build it and run valuable non-UI tests only.

## Working Method

- Discuss and resolve one architectural decision at a time.
- Stay concise and focused; expand deeply only when asked.
- Do not introduce new architectural decisions during implementation.
