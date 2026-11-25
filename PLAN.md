# PLAN.md — Milestone Roadmap & Deferred Scope Tracker

This document tracks progress across all 10 project milestones and maintains the deferred scope backlog.

---

## 1. Milestones Overview

| Milestone | Title | Focus & Deliverables | Status |
|---|---|---|:---:|
| **M1** | **Foundation** | Repo setup, root docs, project config, data validator, 32-car JSON & `CAR_ROSTER_BIBLE.md`, input abstraction, audio bus hierarchy, debug telemetry overlay (<kbd>F3</kbd>), standalone Windows export (`GRIDLETHAL.exe` + `.pck`). | **COMPLETED** |
| **M2** | **Core Feel** | Terrain heightfield, spline test track, reference vehicle (`CarConcept.glb` + procedural fallback), 120Hz Pacejka tire physics, 3 camera modes (Chase, Cockpit, Tactical), procedural engine/tire audio, physics tests. | **COMPLETED** |
| **M3** | **Visual Look** | Forward+ lighting, physical sky shader/HDRI, 4-split sun cascaded shadows, SSAO/SSIL/SSR, filmic tonemapping (ACES/AgX), PBR clearcoat paints, dynamic resolution scaling (DRS), screenshot comparisons against Forza Horizon 5. | **COMPLETED** |
| **M4** | **Circuit Racing & AI** | Spline swept road mesh, curbs, checkpoint gates, race manager (Countdown $\rightarrow$ Racing $\rightarrow$ Results), AI drivers with spline navigation & curvature profiling, 2D radar minimap & race HUD. | **COMPLETED** |
| **M5** | **Vehicular Combat** | 10 core weapons, ballistic rockets with homing, raycast tracers, proximity mines, oil slicks, auto-aim cone, vertex denting, fatal wrecks with fire/smoke, pickups, AI revenge pursuit. | **COMPLETED** |
| **M6** | **Garage & Economy** | 3D garage showroom with rotating turntable, customization (paints, finishes, spoilers), 10 upgrade systems x 5 tiers, 6 driver specialists, save slots, Base64 export/import. | **COMPLETED** |
| **M7** | **Campaign & Biomes** | 4 Regional Biomes (Dust Bowl, Neon Docks, Frozen Pass, Volcano Ridge), 28 campaign missions across 8 game modes, 4 multi-phase boss encounters, expanded 26-weapon arsenal. | **COMPLETED** |
| **M8** | **Progression & Balancing** | 100-level XP curve, 60 career achievements, loot crates, economy balance simulation, debug cheat console (<kbd>F4</kbd>). | **COMPLETED** |
| **M9** | **Multiplayer & Server** | 24-byte binary snapshot codec, client-side prediction & entity interpolation, ENet high-level multiplayer, headless dedicated relay server (`--headless`). | **COMPLETED** |
| **M10**| **Final Polish & Packaging** | Procedural 135 BPM industrial cyber-rock music sequencer, announcer voiceover, accessibility settings, photo mode, replay cam, Windows installer script, final performance pass. | **COMPLETED** |
| **OPEN WORLD** | **FH5 Scale World Map** | 16 km² ($4,000\text{ m} \times 4,000\text{ m}$) open world map across 4 biomes + Festival Hub, Grand Perimeter Highway (64 waypoints), Trans-Continental Expressway, Hillclimb switchbacks, chunk streaming, MultiMesh scenery instancing, and GPS telemetry HUD. | **COMPLETED** |

---

## 2. Deferred Scope List (Cut Priority Order)
As specified in Part 4, if performance or time budgets require scope reduction, items are deferred in this exact sequence:
1. Capture The Flag (CTF) and King of the Hill experimental modes.
2. Replay camera playback engine.
3. Seasonal pass progression track.
4. Per-vehicle mastery challenge trees.
5. Escort/Defend convoy campaign mode.
6. The four lowest-usage secondary weapon variants.

*Non-Cuttable Core*: Driving feel, cameras, PBR car materials/lighting, engine/tire audio synthesis, weapons with visible damage, garage loop, campaign structure, PC & Android build stability.
