# scripts/world/destructible_prop_manager.gd
# Heterogeneous spatial physics & destruction manager for all open-world props (120 Hz Jolt + pooled debris).
class_name DestructiblePropManager
extends Node3D

enum DestructType {
	SOLID_BUILDING,
	SOLID_ROCK,
	HEAVY_SLIDE,
	POLE_SNAP,
	WOOD_SPLINTER,
	CACTUS_BURST,
	LIGHT_PLASTIC_FLICK,
	TREE_SNAP,
	EXPLOSIVE_DRUM
}

const GRID_CELL: float = 96.0
const ACTIVE_RADIUS_SQ: float = 88.0 * 88.0
const DEBRIS_POOL_SIZE: int = 32
const SPARK_POOL_SIZE: int = 12
const COLLIDER_POOL_SIZE: int = 36

var _prop_entries: Array[Dictionary] = []
var _spatial_grid: Dictionary = {} # Vector2i -> Array[int]
var _active_static_pool: Array[StaticBody3D] = []
var _active_static_props: Array[int] = [] # prop_idx bound to collider pool slot

var _debris_pool: Array[RigidBody3D] = []
var _debris_timers: PackedFloat32Array = PackedFloat32Array()
var _debris_cursor: int = 0

var _fx_pool: Array[GPUParticles3D] = []
var _fx_cursor: int = 0

var _last_scan_pos := Vector3(99999.0, 0.0, 99999.0)
var _nearby_breakable_ids: Array[int] = []
var _hidden_xf := Transform3D(Basis.IDENTITY.scaled(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0.0, -9000.0, 0.0))

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 9091

func _ready() -> void:
	_init_pools()

func _init_pools() -> void:
	if not _active_static_pool.is_empty():
		return
	for i: int in range(COLLIDER_POOL_SIZE):
		var sb := StaticBody3D.new()
		sb.name = "PropColPool_%d" % i
		sb.collision_layer = 1
		sb.collision_mask = 1
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.0, 1.0)
		cs.shape = box
		sb.add_child(cs)
		sb.position = Vector3(0.0, -9000.0, 0.0)
		add_child(sb)
		_active_static_pool.append(sb)
		_active_static_props.append(-1)

	_debris_timers.resize(DEBRIS_POOL_SIZE)
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.46, 0.34, 0.22)
	wood_mat.roughness = 0.86

	for i: int in range(DEBRIS_POOL_SIZE):
		var rb := RigidBody3D.new()
		rb.name = "DebrisChunk_%d" % i
		rb.collision_layer = 4
		rb.collision_mask = 1
		rb.mass = 24.0
		rb.freeze = true
		rb.visible = false
		rb.position = Vector3(0.0, -9000.0, 0.0)

		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.65, 0.22, 0.24)
		cs.shape = box
		rb.add_child(cs)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.65, 0.22, 0.24)
		mi.mesh = bm
		mi.material_override = wood_mat.duplicate()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		rb.add_child(mi)

		add_child(rb)
		_debris_pool.append(rb)
		_debris_timers[i] = 0.0

	for i: int in range(SPARK_POOL_SIZE):
		var p := GPUParticles3D.new()
		p.name = "PropFX_%d" % i
		p.one_shot = true
		p.emitting = false
		p.amount = 24
		p.lifetime = 0.75
		p.explosiveness = 0.92
		var pmat := ParticleProcessMaterial.new()
		pmat.direction = Vector3(0.0, 1.0, 0.0)
		pmat.spread = 65.0
		pmat.initial_velocity_min = 6.0
		pmat.initial_velocity_max = 16.0
		pmat.gravity = Vector3(0.0, -14.0, 0.0)
		pmat.scale_min = 0.25
		pmat.scale_max = 0.85
		p.process_material = pmat

		var q := BoxMesh.new()
		q.size = Vector3(0.18, 0.18, 0.18)
		var qm := StandardMaterial3D.new()
		qm.albedo_color = Color(0.95, 0.65, 0.25)
		qm.roughness = 0.7
		q.material = qm
		p.draw_pass_1 = q
		p.position = Vector3(0.0, -9000.0, 0.0)
		add_child(p)
		_fx_pool.append(p)

func register_multimesh_prop_batch(batch_name: String, mm: MultiMesh, base_mesh: Mesh, destruct_type: DestructType, xforms_override: Array[Transform3D] = []) -> void:
	if not mm or not base_mesh:
		return
	var aabb: AABB = base_mesh.get_aabb()
	var count: int = mm.instance_count if xforms_override.is_empty() else mini(mm.instance_count, xforms_override.size())
	for i: int in range(count):
		var xf: Transform3D = xforms_override[i] if i < xforms_override.size() else mm.get_instance_transform(i)
		var sx: float = xf.basis.x.length()
		var sy: float = xf.basis.y.length()
		var sz: float = xf.basis.z.length()
		var world_sz := Vector3(aabb.size.x * sx, aabb.size.y * sy, aabb.size.z * sz)
		var eff_type: DestructType = destruct_type
		if destruct_type == DestructType.TREE_SNAP and maxf(world_sz.x, world_sz.z) > 3.6 and world_sz.y > 7.5:
			eff_type = DestructType.SOLID_ROCK

		var world_ctr: Vector3 = xf * aabb.get_center()
		var entry := {
			"batch": batch_name,
			"mm": mm,
			"mm_idx": i,
			"xf": xf,
			"pos": world_ctr,
			"ground_pos": xf.origin,
			"size": world_sz,
			"radius": maxf(0.55, maxf(world_sz.x, world_sz.z) * 0.45),
			"type": eff_type,
			"broken": false,
			"vel": Vector3.ZERO,
			"sliding": false
		}
		var idx: int = _prop_entries.size()
		_prop_entries.append(entry)
		var k := Vector2i(int(floorf(world_ctr.x / GRID_CELL)), int(floorf(world_ctr.z / GRID_CELL)))
		if not _spatial_grid.has(k):
			var bucket: Array[int] = []
			_spatial_grid[k] = bucket
		(_spatial_grid[k] as Array[int]).append(idx)

func classify_batch_name(batch_name: String) -> DestructType:
	var n: String = batch_name.to_lower()
	if "grass" in n or "bush" in n or "succulent" in n or "fern" in n:
		return DestructType.CACTUS_BURST
	if "saguaro" in n or "yucca" in n or "cactus" in n:
		return DestructType.CACTUS_BURST
	if "explosive" in n or "barrel_red" in n or "barrel_rust" in n or "propane" in n or "lpg" in n or "jerrycan" in n or "welding" in n or "gas_pump" in n:
		return DestructType.EXPLOSIVE_DRUM
	if "cone" in n or "trash_can" in n or "tyre" in n or "tire" in n or "crowd" in n or "plastic" in n:
		return DestructType.LIGHT_PLASTIC_FLICK
	if "lamp" in n or "hydrant" in n or "bollard" in n or "mailbox" in n or "sign" in n or "solar" in n or "searchlight" in n or "pole" in n:
		return DestructType.POLE_SNAP
	if "crate" in n or "pallet" in n or "hay" in n or "bench" in n or "picnic" in n or "fence" in n or "table" in n or "barrels" in n or "lifeguard" in n or "parasol" in n or "rowboat" in n or "barricade" in n or "construction" in n:
		return DestructType.WOOD_SPLINTER
	if "sapling" in n or "joshua" in n or "quiver" in n or "palm" in n or "jacaranda" in n or "island_tree" in n or "pine" in n or "fir" in n:
		return DestructType.TREE_SNAP
	if "barrier" in n or "generator" in n or "vending" in n or "pipes" in n or "seating" in n or "barrel_blue" in n:
		return DestructType.HEAVY_SLIDE
	if "rock" in n or "boulder" in n or "cliff" in n or "arch" in n or "crag" in n:
		return DestructType.SOLID_ROCK
	return DestructType.SOLID_BUILDING

func get_total_prop_count() -> int:
	return _prop_entries.size()

func get_prop_entries() -> Array[Dictionary]:
	return _prop_entries

func get_broken_prop_count() -> int:
	var c: int = 0
	for e: Dictionary in _prop_entries:
		if bool(e["broken"]):
			c += 1
	return c

func step_physics(player_vehicle: RigidBody3D, delta: float) -> void:
	_step_debris_pool(delta)
	if not player_vehicle or _prop_entries.is_empty():
		return

	var car_pos: Vector3 = player_vehicle.global_position
	if car_pos.distance_squared_to(_last_scan_pos) > 16.0:
		_last_scan_pos = car_pos
		_refresh_active_props(car_pos)

	var car_vel: Vector3 = player_vehicle.linear_velocity
	var speed_mps: float = car_vel.length()
	var car_radius: float = 1.68

	for p_idx: int in _nearby_breakable_ids:
		var entry: Dictionary = _prop_entries[p_idx]
		if bool(entry["broken"]):
			continue
		var p_pos: Vector3 = entry["pos"]
		var g_pos: Vector3 = entry["ground_pos"]
		var sz_v: Vector3 = entry["size"]
		var hit_r: float = float(entry["radius"]) + car_radius
		var dx: float = car_pos.x - p_pos.x
		var dz: float = car_pos.z - p_pos.z
		if (dx * dx + dz * dz) > (hit_r * hit_r):
			continue
		if car_pos.y < g_pos.y - 1.5 or car_pos.y > g_pos.y + sz_v.y + 1.2:
			continue
		if speed_mps < 1.8:
			continue
		_trigger_destruction(p_idx, player_vehicle, car_vel)

func force_refresh_near(pos: Vector3) -> void:
	_last_scan_pos = pos
	_refresh_active_props(pos)

func _refresh_active_props(center: Vector3) -> void:
	_nearby_breakable_ids.clear()
	var cx: int = int(floorf(center.x / GRID_CELL))
	var cz: int = int(floorf(center.z / GRID_CELL))
	var solids: Array[Dictionary] = []

	for gz: int in range(cz - 1, cz + 2):
		for gx: int in range(cx - 1, cx + 2):
			var k := Vector2i(gx, gz)
			if not _spatial_grid.has(k):
				continue
			var bucket: Array[int] = _spatial_grid[k]
			for p_idx: int in bucket:
				var entry: Dictionary = _prop_entries[p_idx]
				if bool(entry["broken"]):
					continue
				var p_pos: Vector3 = entry["pos"]
				var d2: float = center.distance_squared_to(p_pos)
				if d2 > ACTIVE_RADIUS_SQ:
					continue
				var dt: int = int(entry["type"])
				if dt == DestructType.SOLID_BUILDING or dt == DestructType.SOLID_ROCK:
					solids.append({"idx": p_idx, "d2": d2})
				else:
					_nearby_breakable_ids.append(p_idx)

	solids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d2"]) < float(b["d2"]))
	var active_count: int = mini(solids.size(), COLLIDER_POOL_SIZE)
	for s_i: int in range(COLLIDER_POOL_SIZE):
		var sb: StaticBody3D = _active_static_pool[s_i]
		if s_i < active_count:
			var p_idx: int = int(solids[s_i]["idx"])
			var entry: Dictionary = _prop_entries[p_idx]
			var sz: Vector3 = entry["size"]
			var xf: Transform3D = entry["xf"]
			sb.global_transform = Transform3D(xf.basis.orthonormalized(), entry["pos"] as Vector3)
			var cs := sb.get_child(0) as CollisionShape3D
			if cs and cs.shape is BoxShape3D:
				(cs.shape as BoxShape3D).size = Vector3(maxf(0.5, sz.x * 0.85), maxf(0.8, sz.y), maxf(0.5, sz.z * 0.85))
			sb.set_meta("prop_idx", p_idx)
			_active_static_props[s_i] = p_idx
		else:
			sb.global_position = Vector3(0.0, -9000.0, 0.0)
			_active_static_props[s_i] = -1

func _trigger_destruction(p_idx: int, car: RigidBody3D, car_vel: Vector3) -> void:
	var entry: Dictionary = _prop_entries[p_idx]
	entry["broken"] = true
	var mm: MultiMesh = entry["mm"]
	var mm_idx: int = int(entry["mm_idx"])
	mm.set_instance_transform(mm_idx, _hidden_xf)

	var dt: DestructType = int(entry["type"]) as DestructType
	var p_pos: Vector3 = entry["pos"]
	var sz: Vector3 = entry["size"]
	var imp_dir: Vector3 = car_vel.normalized() if car_vel.length_squared() > 0.2 else -car.global_transform.basis.z
	var speed: float = car_vel.length()

	match dt:
		DestructType.WOOD_SPLINTER:
			car.linear_velocity = car_vel * 0.96
			_spawn_debris_burst(p_pos, imp_dir, speed, 5, Color(0.52, 0.36, 0.22), Vector3(0.85, 0.16, 0.22), 18.0)
			_trigger_fx(p_pos, Color(0.72, 0.56, 0.36), 1.0)
		DestructType.CACTUS_BURST:
			car.linear_velocity = car_vel * 0.985
			_spawn_debris_burst(p_pos, imp_dir, speed, 4, Color(0.24, 0.42, 0.20), Vector3(0.45, 0.40, 0.40), 14.0)
			_trigger_fx(p_pos, Color(0.32, 0.55, 0.25), 0.9)
		DestructType.LIGHT_PLASTIC_FLICK:
			car.linear_velocity = car_vel * 0.992
			_spawn_debris_burst(p_pos, imp_dir, speed * 1.25, 2, Color(0.92, 0.42, 0.08), Vector3(0.55, 0.65, 0.55), 8.0)
			_trigger_fx(p_pos, Color(0.82, 0.80, 0.76), 0.6)
		DestructType.POLE_SNAP:
			car.linear_velocity = car_vel * 0.88
			var is_hydrant: bool = "hydrant" in str(entry["batch"]).to_lower()
			var pole_col := Color(0.85, 0.18, 0.12) if is_hydrant else Color(0.28, 0.30, 0.34)
			var pole_sz := Vector3(0.42, 0.95, 0.42) if is_hydrant else Vector3(0.30, minf(sz.y * 0.85, 4.2), 0.30)
			_spawn_debris_burst(p_pos + Vector3(0.0, 0.6, 0.0), imp_dir, speed * 0.9, 2, pole_col, pole_sz, 55.0)
			_trigger_fx(p_pos, Color(0.55, 0.82, 1.0) if is_hydrant else Color(1.0, 0.72, 0.24), 2.4 if is_hydrant else 1.2)
		DestructType.TREE_SNAP:
			car.linear_velocity = car_vel * 0.82
			_spawn_debris_burst(p_pos + Vector3(0.0, 0.8, 0.0), imp_dir, speed * 0.75, 3, Color(0.36, 0.26, 0.18), Vector3(0.45, 2.4, 0.45), 65.0)
			_trigger_fx(p_pos + Vector3(0.0, 1.8, 0.0), Color(0.26, 0.44, 0.22), 1.4)
		DestructType.HEAVY_SLIDE:
			car.linear_velocity = car_vel * 0.72
			var slide_sz := Vector3(clampf(sz.x * 0.75, 0.8, 2.2), clampf(sz.y * 0.85, 0.7, 1.4), clampf(sz.z * 0.75, 0.8, 2.2))
			_spawn_debris_burst(p_pos, imp_dir, speed * 0.58, 1, Color(0.56, 0.55, 0.53), slide_sz, 180.0)
			_trigger_fx(p_pos, Color(0.68, 0.64, 0.58), 1.35)
		DestructType.EXPLOSIVE_DRUM:
			car.apply_central_impulse(Vector3(0.0, car.mass * 2.2, 0.0) - imp_dir * (car.mass * 4.5))
			_spawn_debris_burst(p_pos, imp_dir, speed * 1.4, 4, Color(0.18, 0.16, 0.16), Vector3(0.55, 0.55, 0.40), 22.0)
			_trigger_fx(p_pos, Color(1.0, 0.42, 0.08), 2.8)

func _spawn_debris_burst(origin: Vector3, dir: Vector3, speed: float, count: int, col: Color, chunk_sz: Vector3, mass_val: float) -> void:
	for _i: int in range(count):
		var rb: RigidBody3D = _debris_pool[_debris_cursor]
		var slot: int = _debris_cursor
		_debris_cursor = (_debris_cursor + 1) % DEBRIS_POOL_SIZE

		rb.freeze = false
		rb.visible = true
		rb.mass = mass_val
		rb.global_position = origin + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.2, 1.1), _rng.randf_range(-0.5, 0.5))
		rb.global_rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf() * TAU, _rng.randf_range(-0.4, 0.4))
		rb.linear_velocity = dir * maxf(8.0, speed * _rng.randf_range(0.65, 1.25)) + Vector3(_rng.randf_range(-5.5, 5.5), _rng.randf_range(3.5, 9.5), _rng.randf_range(-5.5, 5.5))
		rb.angular_velocity = Vector3(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0), _rng.randf_range(-8.0, 8.0))

		var cs := rb.get_child(0) as CollisionShape3D
		if cs and cs.shape is BoxShape3D:
			(cs.shape as BoxShape3D).size = chunk_sz
		var mi := rb.get_child(1) as MeshInstance3D
		if mi and mi.mesh is BoxMesh:
			(mi.mesh as BoxMesh).size = chunk_sz
			var mat := mi.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = col
		_debris_timers[slot] = 3.2

func _trigger_fx(pos: Vector3, col: Color, burst_mult: float) -> void:
	var p: GPUParticles3D = _fx_pool[_fx_cursor]
	_fx_cursor = (_fx_cursor + 1) % SPARK_POOL_SIZE
	p.global_position = pos + Vector3(0.0, 0.5, 0.0)
	var pm := p.process_material as ParticleProcessMaterial
	if pm:
		pm.initial_velocity_min = 6.0 * burst_mult
		pm.initial_velocity_max = 15.0 * burst_mult
	var bm := p.draw_pass_1 as BoxMesh
	if bm and bm.material is StandardMaterial3D:
		(bm.material as StandardMaterial3D).albedo_color = col
	p.restart()
	p.emitting = true

func _step_debris_pool(delta: float) -> void:
	for i: int in range(DEBRIS_POOL_SIZE):
		if _debris_timers[i] > 0.0:
			_debris_timers[i] -= delta
			if _debris_timers[i] <= 0.0:
				var rb: RigidBody3D = _debris_pool[i]
				rb.freeze = true
				rb.visible = false
				rb.linear_velocity = Vector3.ZERO
				rb.angular_velocity = Vector3.ZERO
				rb.global_position = Vector3(0.0, -9000.0, 0.0)
