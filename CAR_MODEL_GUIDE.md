# CAR_MODEL_GUIDE.md — 3D Vehicle Model Specifications & Export Conventions

This guide defines the node naming conventions, spatial orientation, pivots, and Blender export standards for all vehicles in **GRIDLETHAL**.

---

## 1. Units, Scale & Orientation
- **Engine**: Godot 4.x
- **Units**: Metric (1.0 unit = 1.0 meter).
- **Forward Vector**: $-Z$ ($+Z$ is rear).
- **Up Vector**: $+Y$ ($-Y$ is ground).
- **Right Vector**: $+X$ ($-X$ is driver left).
- **Origin / Root Pivot**: Ground-center directly beneath the center of the chassis wheelbase ($Y = 0.0\text{ m}$).

---

## 2. Mandatory Node Hierarchy & Naming
Every imported vehicle glTF/GLB (and procedural mesh) must expose the following named nodes:

```text
Root / CarRoot
├── body                  (MeshInstance3D: Main chassis, bumpers, engine bay)
├── glass                 (MeshInstance3D: Windshield, side/rear windows)
├── wheel_FL              (MeshInstance3D: Front-Left wheel + tire + rim)
├── wheel_FR              (MeshInstance3D: Front-Right wheel + tire + rim)
├── wheel_RL              (MeshInstance3D: Rear-Left wheel + tire + rim)
├── wheel_RR              (MeshInstance3D: Rear-Right wheel + tire + rim)
├── brake_caliper_FL      (Node3D / Mesh: Optional independent caliper)
├── brake_caliper_FR      (Node3D / Mesh: Optional independent caliper)
├── brake_caliper_RL      (Node3D / Mesh: Optional independent caliper)
├── brake_caliper_RR      (Node3D / Mesh: Optional independent caliper)
├── headlights            (MeshInstance3D / OmniLight3D: Forward lighting)
├── taillights            (MeshInstance3D / OmniLight3D: Reverse/brake illumination)
├── interior              (MeshInstance3D: Dashboard, steering wheel, seats, roll cage)
├── spoiler               (MeshInstance3D: Rear aerodynamic wing; detachable)
├── hood                  (MeshInstance3D: Engine hood; detachable on heavy impact)
├── door_L                (MeshInstance3D: Left door; detachable)
└── door_R                (MeshInstance3D: Right door; detachable)
```

### Wheel Pivot Rules
- Wheel meshes (`wheel_FL`, `wheel_FR`, `wheel_RL`, `wheel_RR`) **MUST** have their local origin centered exactly at their axle center.
- Rotating the wheel node around local $X$-axis produces rolling forward; rotating around local $Y$-axis produces steering.

---

## 3. Materials & Shaders
- **Car Paint**: Mesh with material name matching `Paint*` or slot 0. Must use `StandardMaterial3D` or `ShaderMaterial` supporting:
  - `clearcoat = 1.0`
  - `clearcoat_roughness = 0.04`
  - `metallic = 0.82`
  - `roughness = 0.18`
- **Glass**: `transparency = ALPHA`, `roughness = 0.05`, `metallic = 0.1`, `albedo_color = Color(0.1, 0.15, 0.2, 0.4)`.
- **Tire Rubber**: `roughness = 0.85`, `metallic = 0.0`, `albedo_color = Color(0.08, 0.08, 0.08)`.
- **Rims**: `roughness = 0.25`, `metallic = 0.95`.

---

## 4. Blender glTF 2.0 Export Checklist
When exporting from Blender to `.glb`:
1. [x] Apply all scale and rotation transforms (<kbd>Ctrl</kbd> + <kbd>A</kbd> $\rightarrow$ All Transforms).
2. [x] Ensure forward direction of the vehicle points towards $-Y$ in Blender (which converts to $-Z$ in glTF/Godot).
3. [x] Set wheel mesh origins to geometry center (<kbd>Set Origin</kbd> $\rightarrow$ <kbd>Origin to Center of Mass (Surface)</kbd>).
4. [x] Export Format: **glTF Binary (.glb)**.
5. [x] Include: **Selected Objects**, **Custom Properties**.
6. [x] Geometry: **Apply Modifiers**, **Normals**, **Tangents**, **UVs**.
7. [x] Materials: **Export Materials**.
8. [x] Animation: Disable if unneeded (or include if doors/spoilers are rigged).
9. [x] Verify file size target: $< 20\text{ MB}$ per car.
