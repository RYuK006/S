# STATE.md — Public Interface Contracts & Caller Architecture

This document specifies the public API, signals, data shapes, and cross-module caller dependencies for **GRIDLETHAL**.

---

## 1. Core Modules

### `DataValidator` (`scripts/core/data_validator.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: Validates all JSON files in `data/` at boot time, throwing descriptive errors on missing or invalid fields.
- **Public API**:
  - `validate_all() -> Dictionary`: Returns `{ "success": bool, "errors": Array[String] }`.
  - `validate_vehicles(data: Dictionary) -> Array[String]`
  - `validate_weapons(data: Dictionary) -> Array[String]`
  - `validate_upgrades(data: Dictionary) -> Array[String]`
  - `validate_economy(data: Dictionary) -> Array[String]`
- **Called by**: `MainScene._ready()`, `test_data_validation.gd`.

### `InputManager` (`scripts/core/input_manager.gd`)
- **Inherits**: `Node`
- **Purpose**: Abstracts Keyboard/Mouse, Gamepad (XInput, DualSense, Switch Pro), and Mobile Virtual Touch inputs into unified analog axes and actions.
- **Signals**:
  - `input_device_changed(device_type: String)`
  - `action_triggered(action_name: String)`
- **Public API**:
  - `get_steer() -> float`: Range $[-1.0, 1.0]$.
  - `get_throttle() -> float`: Range $[0.0, 1.0]$.
  - `get_brake() -> float`: Range $[0.0, 1.0]$.
  - `is_handbrake() -> bool`
  - `is_nitro() -> bool`
  - `is_fire_primary() -> bool`
  - `is_fire_roof() -> bool`
  - `is_fire_rear() -> bool`
- **Called by**: `VehicleController._physics_process()`.

### `SaveManager` (`scripts/core/save_manager.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: Atomic JSON persistence in `user://saves/` with versioning, rolling backups, and Base64 export/import.
- **Signals**:
  - `save_completed(slot: int)`
  - `load_completed(slot: int)`
- **Public API**:
  - `load_slot(slot_idx: int) -> Dictionary`
  - `save_slot(slot_idx: int, state: Dictionary) -> bool`
  - `export_save_base64(slot_idx: int) -> String`
  - `import_save_base64(slot_idx: int, b64_str: String) -> bool`
- **Called by**: `GarageController`, `ProgressionManager`, `RaceManager`.

---

## 2. Vehicle Simulation Modules

### `VehicleController` (`scripts/vehicle/vehicle_controller.gd`)
- **Inherits**: `RigidBody3D`
- **Purpose**: 120Hz custom physics simulation using raycast suspension, Pacejka tire curves, transmission, aerodynamics, and nitro.
- **Signals**:
  - `gear_shifted(new_gear: int)`
  - `nitro_changed(amount: float)`
  - `vehicle_damaged(damage: float, attacker_node: Node)`
  - `vehicle_wrecked()`
- **Public Properties**:
  - `car_id: String`: Unique recipe ID loaded from `data/vehicles.json` with fallback.
  - `speed_kmh: float`: Current ground speed in km/h.
  - `engine_rpm: float`: Drivetrain RPM with load-dependent torque scaling.
  - `current_gear: int`: Automatic 5-speed transmission gear (1..5).
  - `throttle_input: float`, `brake_input: float`, `steer_input: float`: Smoothed analog control states.
  - `handbrake_input: bool`: Drifting handbrake modifier.
  - `nitro_active: bool`, `nitro_amount: float`: Nitro boost state.
  - `health: float`, `max_health: float`: Vehicle structural integrity.
  - `wheels: Array[RaycastWheel]`: 4-corner suspension assemblies (`front_left_wheel`, `front_right_wheel`, `rear_left_wheel`, `rear_right_wheel`).
- **Public API**:
  - `self_right_car()`: Recovers vehicle if inverted.
  - `apply_damage(amount: float, hit_point: Vector3, attacker = null)`
  - `apply_repair(amount: float)`
- **Called by**: `InputManager`, `DebugOverlay`, `ProceduralAudioEngine`, `CameraRig`, `TrackTestController`.

### `RaycastWheel` (`scripts/vehicle/raycast_wheel.gd`)
- **Inherits**: `Node3D`
- **Purpose**: 4-corner suspension strut using RayCast3D, Pacejka Magic Formula, load sensitivity, bump/rebound damping, bump stops, and anti-roll bar coupling.
- **Public Properties**:
  - `is_grounded: bool`
  - `compression: float`: Suspension travel displacement (m).
  - `normal_force: float`: Ground contact normal force $F_z$ (N).
  - `slip_angle: float`: Lateral tire slip angle $\alpha$ (rad).
  - `slip_ratio: float`: Longitudinal tire slip ratio $\kappa$.
  - `surface_type: String`: Detected collider surface meta (`asphalt_dry`, `dirt`, `grass`).
  - `surface_mu: float`: Friction coefficient multiplier.
  - `wheel_visual: Node3D`: Visual wheel mesh bound to suspension kinematics.
- **Public API**:
  - `setup(config: Dictionary, tire_cfg: Dictionary)`
  - `update_suspension(chassis: RigidBody3D, dt: float) -> Vector3`
- **Called by**: `VehicleController`.

### `CameraRig` (`scripts/vehicle/camera_rig.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Multi-mode camera rig supporting Chase, Cockpit, and Tactical views with dynamic speed FOV.
- **Enums**:
  - `CameraMode`: `CHASE = 0`, `COCKPIT = 1`, `TACTICAL = 2`.
- **Public Properties**:
  - `target_vehicle: VehicleController`
  - `current_mode: CameraMode`
  - `camera: Camera3D`
- **Called by**: `TrackTestController`.

### `SplineTrack` (`scripts/race/spline_track.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Catmull-Rom swept asphalt circuit generator with curbs, trimesh collision, and checkpoint gates.
- **Public Properties**:
  - `track_points: Array[Dictionary]`: Sampled spline points with `pos`, `forward`, `right`, `up`, `dist`.
  - `total_length: float`: Circuit lap distance (m).
  - `checkpoints: Array[Area3D]`: Checkpoint gate triggers.
- **Public API**:
  - `setup_circuit()`
  - `get_closest_track_point(pos: Vector3) -> Dictionary`
- **Called by**: `TrackTestController`, `RaceManager`.

### `TrackTestController` (`scripts/race/track_test_controller.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Milestone 2 scene coordinator wiring spline track, player car, audio engine, camera rig, and automated `--screenshot` frame capture.
- **Called by**: `scenes/track_test.tscn`.

### `ProceduralCarMesh` (`scripts/vehicle/procedural_car_mesh.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Procedural fallback 3D chassis and wheels exposing identical node hierarchy to imported GLBs (`body`, `wheel_FL`, `wheel_FR`, `wheel_RL`, `wheel_RR`, `glass`, `headlights`, `taillights`).
- **Public API**:
  - `build_mesh(recipe: Dictionary, color: Color) -> Node3D`
  - `apply_damage_dent(contact_point: Vector3, impulse: float)`

---

## 3. Audio & Telemetry Modules

### `ProceduralAudioEngine` (`scripts/audio/procedural_audio_engine.gd`)
- **Inherits**: `Node`
- **Purpose**: Pink noise combustion pulse train synthesizer and tire squeal generator routed to Godot `Engine` and `Tyres` audio buses.
- **Public API**:
  - `update_audio(rpm: float, throttle: float, boost: float, max_slip: float)`
  - `play_impact_sound(surface: String, speed_norm: float)`
- **Called by**: `MainScene._process()`, `VehicleController`.

### `DebugOverlay` (`scripts/ui/debug_overlay.gd`)
- **Inherits**: `Control`
- **Purpose**: Real-time telemetry HUD toggled with <kbd>F3</kbd> on desktop or 3-finger tap on touch devices.
- **Public API**:
  - `toggle_visible()`
  - `set_target_vehicle(vehicle: Node3D)`
- **Called by**: `MainScene`.

---

## 4. Weapons, Combat & Progression Modules

### `WeaponSystem` (`scripts/weapons/weapon_system.gd`) & `Projectile` (`scripts/weapons/projectile.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Modular combat manager supporting 26 weapons across FRONT, ROOF, REAR, MELEE, and DEFENSIVE slots, with sub-stepped ballistic rockets, raycast hitscans, proximity mines, and auto-aim assistance.
- **Called by**: `VehicleController`, `TrackTestController`.

### `GarageController` (`scripts/ui/garage_controller.gd`)
- **Inherits**: `Node3D`
- **Purpose**: 3D showroom with rotating turntable platform, car inspection, 10 upgrade systems x 5 tiers, paint customization (metallic, gloss, satin, matte, pearl), and driver specialist perks.
- **Called by**: `scenes/garage.tscn`.

### `BiomeManager` (`scripts/race/biome_manager.gd`)
- **Inherits**: `Node`
- **Purpose**: Controls active biome lighting, atmosphere, and surface grip scaling across Dust Bowl, Neon Docks, Frozen Pass, and Volcano Ridge.
- **Called by**: `TrackTestController`, `RaceManager`.

### `BossManager` (`scripts/race/boss_manager.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: Orchestrates 4 multi-phase boss encounters with phase transition thresholds and escalating attack patterns.
- **Called by**: `RaceManager`, `TestM7CampaignBench`.

### `ProgressionSystem` (`scripts/core/progression_system.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: 100-level non-linear XP curve, 60 career achievements, and economy pacing simulation.
- **Called by**: `GarageController`, `RaceManager`.

### `CheatConsole` (`scripts/ui/cheat_console.gd`)
- **Inherits**: `CanvasLayer`
- **Purpose**: Developer cheat terminal toggled with <kbd>F4</kbd> (cash, level, god mode, unlock all vehicles and weapons).
- **Called by**: `TrackTestController`, `GarageController`.

---

## 5. Netcode, Audio Synthesis & Final Shipped Build

### `NetworkManager` (`scripts/net/network_manager.gd`) & `NetSnapshot` (`scripts/net/net_snapshot.gd`)
- **Inherits**: `Node`
- **Purpose**: ENet client/server multiplayer, 24-byte binary snapshot codec, and 100ms jitter buffer entity interpolation.
- **Called by**: `MainScene`, dedicated relay runner (`--server`).

### `MusicSequencer` (`scripts/audio/music_sequencer.gd`) & `AnnouncerSystem` (`scripts/audio/announcer_system.gd`)
- **Inherits**: `Node`
- **Purpose**: Procedural 135 BPM cyber-rock drum sequencer (Anti-Buzz zero DC pink noise synthesis) and announcer voiceover/combat stingers.
- **Called by**: `RaceManager`, `MainScene`.

### `SettingsManager` (`scripts/core/settings_manager.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: Atomic settings persistence in `user://settings.json` for audio volumes, graphics DRS, screen shake, and colorblind filters.
- **Called by**: `MainScene`, `GarageController`.

---

## 6. Open World System (FH5 Scale Architecture)

### `OpenWorldConfig` (`scripts/world/open_world_config.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: Map layout constants (4,000m x 4,000m, 500m chunk size, 8x8 grid = 64 chunks), 5 biome profiles (Frozen Pass, Volcano Ridge, Dust Bowl, Neon Coast, Festival Hub) with friction, surface types, and color definitions.
- **Called by**: `TerrainGenerator`, `RoadNetwork`, `SceneryPopulator`, `OpenWorldManager`.

### `TerrainGenerator` (`scripts/world/terrain_generator.gd`)
- **Inherits**: `RefCounted`
- **Purpose**: 3-noise octave continuous heightfield, smooth quadrant and festival hub blending, surface normal calculation, and 500m `ArrayMesh` + `ConcavePolygonShape3D` chunk collision generation.
- **Public API**:
  - `get_height(x: float, z: float) -> float`
  - `get_normal(x: float, z: float, step: float = 1.0) -> Vector3`
  - `generate_chunk_mesh(chunk_x: int, chunk_z: int, resolution: int = 32) -> MeshInstance3D`
- **Called by**: `OpenWorldManager`, `RoadNetwork`, `SceneryPopulator`, `TestOpenWorldBench`.

### `RoadNetwork` (`scripts/world/road_network.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Generates arterial asphalt road ribbon meshes with PBR materials and physics collision shapes:
  - Grand Perimeter Highway (64 waypoints, 14m wide, 3.2km loop).
  - Trans-Continental Expressway (East-West arterial connector).
  - Frozen Pass Mountain Hillclimb (Catmull-Rom switchback hairpin curves).
- **Public API**:
  - `build_open_world_roads() -> void`
  - `highway_waypoints: Array[Vector3]`
- **Called by**: `OpenWorldManager`, `TestOpenWorldBench`.

### `SceneryPopulator` (`scripts/world/scenery_populator.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Batched `MultiMeshInstance3D` generation for massive open world roadside decoration:
  - Highway dual-side light poles and crash barriers.
  - Alpine pine forests (NW peaks).
  - Desert boulder clusters and saguaro cacti (SW dunes).
  - Volcanic basalt spires (NE caldera).
  - Industrial shipping containers and dock cranes (SE harbor).
  - Festival entry archway and stage banners.
- **Public API**:
  - `populate_world_scenery() -> void`
- **Called by**: `OpenWorldManager`, `TestOpenWorldBench`.

### `OpenWorldManager` (`scripts/world/open_world_manager.gd`)
- **Inherits**: `Node3D`
- **Purpose**: Dynamic chunk streaming ($5 \times 5$ active radius, $2,500\text{ m} \times 2,500\text{ m}$ loaded area), real-time player GPS & Biome HUD, vehicle spawn at central hub, and `--screenshot` visual test verification.
- **Called by**: `scenes/open_world.tscn`.
