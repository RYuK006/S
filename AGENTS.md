# AGENTS.md — Permanent Rules for GRIDLETHAL Development

This document defines the mandatory, permanent architectural and engineering rules for all development sessions of **GRIDLETHAL**. Every agent must read and adhere strictly to these rules before authoring or modifying code.

---

## 1. Engine & Language Rules
1. **Engine**: Godot 4 (latest stable 4.x), Forward+ Vulkan on desktop, Mobile renderer on mobile.
2. **Language**: GDScript with strict static typing everywhere (`: Type`, `-> ReturnType`, `@export var name: Type`). No dynamic untyped variables, no `Variant` unless explicitly handling generic serialization.
3. **Dependencies**: Zero C#, zero GDExtension, zero paid addons. Only permissive MIT/CC0 addons vendored into `addons/`.
4. **Script Length & Structure**:
   - Single responsibility per file.
   - All scripts strictly under 600 lines.
   - Signals over direct node lookups; never hardcode parent-path node traversals (`get_parent().get_parent()`).
5. **Decoupled Simulation & Physics**:
   - Vehicle physics and race simulation are strictly decoupled from visual nodes.
   - Simulation runs at a deterministic fixed **120 Hz** physics step (`physics_ticks_per_second = 120`).
   - Simulation logic must run headless without visual nodes for automated tests and multiplayer netcode.
6. **Vehicle Physics Mandate**:
   - Custom physics: one `RigidBody3D` per car with 4-corner raycast suspension.
   - Simplified Pacejka Magic Formula tire model with load sensitivity and friction ellipse coupling ($F_x, F_y$).
   - Drivetrain with non-linear torque curves, 5-speed transmission, open/limited-slip differential, aerodynamic downforce/drag, and nitro boost.
   - **Strictly FORBIDDEN**: Do NOT use Godot's built-in `VehicleBody3D` or `VehicleWheel3D`.
7. **Performance & Memory**:
   - Object pools for all projectiles, particles, decals, debris, and audio players.
   - Zero per-frame allocations in hot paths (reuse `Vector3`, `Transform3D`, `Basis` temporaries).
   - Use `MultiMeshInstance3D` for scenery, vegetation, and barriers.
   - Occlusion culling, LODs, and visibility ranges on all world geometry.
8. **Defensive Programming & Telemetry**:
   - Wrap startup in defensive checks and error boundaries.
   - Live telemetry overlay (<kbd>F3</kbd> on PC, 3-finger tap on mobile): FPS, frame time (ms), draw calls, triangle count, physics time, active audio voices, speed, RPM, gear, slip angle per wheel, surface grip, suspension travel.
   - Log diagnostic events cleanly to `user://logs/`.
9. **Save System**:
   - Versioned JSON in `user://saves/` with atomic writes (write to temporary file, flush, rename).
   - Rolling backups and schema migration functions (`saveVersion`).
   - Self-repairing schema validation that discards corrupt payloads without crashing.
   - Base64 export/import string representation.
10. **Determinism**:
    - One seeded `RandomNumberGenerator` for all gameplay logic (weapons, AI decisions, physics variance).
    - Unseeded `randf()` permitted only for non-gameplay cosmetic juice (sparks, smoke puff angle).

---

## 2. Visual Targets (Forza Horizon 5 Fidelity Target)
1. **Desktop (Forward+ / High & Ultra)**:
   - Physical sky shader / CC0 HDRIs in `assets/hdri/`.
   - Directional sun with 4-split cascaded shadow maps (PCF soft shadows, texel-snapped).
   - SSAO, SSIL, SSR on asphalt and car paint.
   - Volumetric fog, light shafts / god rays, bloom/glow.
   - ACES or AgX filmic tone mapping with per-region color grading.
   - Wet-road shader with noise-driven puddle reflections and tire spray.
2. **Mobile (Mobile Renderer / Low & Medium)**:
   - Baked reflection probes, single shadow cascade, simplified bloom, vignette.
   - Dynamic Resolution Scaling (DRS) targeting 60 FPS (or 30 FPS floor) with thermal throttling guard.
3. **Vehicle Materials & Paint**:
   - PBR `StandardMaterial3D` / custom shaders with clearcoat ($1.0$), clearcoat roughness ($0.03\dots0.15$), metalness ($0.6\dots0.9$).
   - Metal-flake normal maps, pearl color-shift, matte, satin, chrome, and rusty primer finishes.
   - Vertex dent displacement driven by impact buffer; detachable panels; cracked glass states.

---

## 3. Audio Engineering Mandate (Anti-Buzz Rule)
1. **Audio Server Buses**:
   - 9-bus hierarchy: Master $\rightarrow$ Engine, Weapons, Impacts, Tyres, Ambience, Music, UI, Voice.
   - Dedicated master compressor and ceiling limiter ($0\text{ dBFS}$ ceiling).
2. **Procedural Synthesis Standards**:
   - **No Raw Drone Oscillators**: Strictly forbidden to use raw sawtooth, square, or triangle drones for engines or impacts.
   - Use layered pink noise filtered with zero DC offset ($DC = 0.00000$), firing pulse trains, and modal resonant filters.
   - RPM pitch-shift, crossfaded on-load and off-load buffers.
   - 32-voice cap on mobile, 48-voice cap on desktop.

---

## 4. Verification Mandate
1. Headless test verification: `.\tools\test.ps1` must pass 100% with zero errors and zero warnings.
2. Visual check: run with `--screenshot` to generate `build/screenshots/*.png` after every graphical change.
3. Every file created or edited must be committed one-by-one with author `RYuK006` and pushed to remote GitHub repository.
