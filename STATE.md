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
- **Purpose**: 120Hz custom physics simulation using raycast suspension, Pacejka tire curves, transmission, and nitro.
- **Signals**:
  - `gear_shifted(new_gear: int)`
  - `nitro_changed(amount: float)`
  - `vehicle_damaged(damage: float, attacker_node: Node)`
  - `vehicle_wrecked()`
- **Public Properties**:
  - `speed_kmh: float`
  - `engine_rpm: float`
  - `current_gear: int`
  - `nitro_amount: float`
  - `health: float`, `max_health: float`
  - `is_wrecked: bool`
- **Called by**: `InputManager` (sets inputs), `RaceHUD`, `ProceduralAudioEngine`, `CameraRig`.

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
