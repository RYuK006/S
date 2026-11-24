# GRIDLETHAL

A high-fidelity 3D realistic vehicular-combat racing simulator built in Godot 4.7 Forward+ Vulkan.

---

## 1. Quick Start (Windows PowerShell)

### Launch the Game
```powershell
.\tools\run.ps1
```
Or directly via Godot CLI:
```powershell
.\tools\godot.cmd res://scenes/main.tscn
```

### Run Headless Test Suites
```powershell
.\tools\test.ps1
```
Or directly:
```powershell
.\tools\godot.cmd --headless -s res://tests/run_all.gd
```

### Export Windows Standalone Binary
```powershell
.\tools\export_windows.ps1
```
Outputs `build/windows/GRIDLETHAL.exe` with `build/windows/GRIDLETHAL.pck`.

### Visual Snapshot Verification
```powershell
.\tools\godot.cmd res://scenes/main.tscn --screenshot
```
Saves screenshot to `build/screenshots/`.

---

## 2. Controls

| Input Action | Keyboard / Mouse | Gamepad (Xbox / DualSense) |
|---|---|---|
| **Throttle / Accelerate** | <kbd>W</kbd> / <kbd>Up Arrow</kbd> | Right Trigger ($RT / R2$) |
| **Brake / Reverse** | <kbd>S</kbd> / <kbd>Down Arrow</kbd> | Left Trigger ($LT / L2$) |
| **Steer Left / Right** | <kbd>A</kbd> / <kbd>D</kbd> or Left / Right | Left Thumbstick ($X\text{-axis}$) |
| **Handbrake / Drift** | <kbd>Space</kbd> | <kbd>A</kbd> (Cross $\times$) / <kbd>B</kbd> (Circle $\bigcirc$) |
| **Nitro Boost** | <kbd>Left Shift</kbd> | <kbd>X</kbd> (Square $\square$) / Right Bumper ($RB / R1$) |
| **Primary Weapon** | Left Click / <kbd>J</kbd> | Right Bumper ($RB / R1$) |
| **Roof Weapon (Rockets)** | Right Click / <kbd>K</kbd> | <kbd>Y</kbd> (Triangle $\triangle$) |
| **Rear Weapon (Mines)** | <kbd>L</kbd> / <kbd>E</kbd> | Left Bumper ($LB / L1$) |
| **Cycle Camera** | <kbd>C</kbd> | D-Pad Down |
| **Toggle Telemetry** | <kbd>F3</kbd> | 3-Finger Tap (Mobile) |
| **Toggle Cheats** | <kbd>F4</kbd> | Select / Back |

---

## 3. Project Architecture

- **`scripts/`**: Statically typed GDScript logic decoupled from rendering (runs at 120Hz physics).
- **`data/`**: Data-driven JSON definitions for all 32 vehicles, 26 weapons, 10 upgrade systems, and economy tables.
- **`assets/models/cars/`**: Photorealistic CC0 3D models (`CarConcept.glb`) plus procedural fallback generator.
- **`tools/`**: PowerShell automation scripts for running, testing, and exporting.
- **`tests/`**: Headless regression suites for physics, audio, data schemas, and netcode.
