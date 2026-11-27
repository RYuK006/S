# scripts/world/biome_props_builder.gd
# Builds Hero Festival Hub paddock structures, Dust Bowl sandstone arches, Coast container ports, & Volcano fumaroles.
class_name BiomePropsBuilder
extends RefCounted

const TerrainGenerator = preload("res://scripts/world/terrain_generator.gd")
const RoadNetwork = preload("res://scripts/world/road_network.gd")
const PropMeshUtils = preload("res://scripts/world/prop_mesh_utils.gd")
const VisualPipeline = preload("res://scripts/core/visual_pipeline.gd")

static func build_festival_hub_arena(parent: Node3D, tg: TerrainGenerator, rn: RoadNetwork, clear_fn: Callable, mm_fn: Callable) -> void:
	# 1. Position Festival Main Stage Canopy cleanly on the Paddock Plaza apron (never obstructing the Start Grid lane!)
	var canopy_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/festival_canopy_tent.glb", 0.44, 0.05)
	if canopy_mesh and clear_fn.call(-29.0, -48.0, 12.0, -1.0):
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_FestivalStartCanopy"
		mi.mesh = canopy_mesh
		mi.position = Vector3(-29.0, tg.get_height(-29.0, -48.0) + 0.05, -48.0)
		mi.rotation.y = PI * 0.42
		parent.add_child(mi)

	# Glowing Horizon Festival Start/Finish Overhead Signboard Gantry (clean matte steel truss + orange/cyan LED strips)
	_build_horizon_start_arch(parent, tg, Vector3(0.0, tg.get_height(0.0, -2.0) + 0.34, -2.0))

	# 2. Festival Concert Geo-Domes flanking Paddock Plazas on left and right of Starting Grid
	var dome_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/festival_geodome.glb", 0.96, 0.05)
	if dome_mesh:
		var d_xforms: Array[Transform3D] = [
			Transform3D(Basis(Vector3.UP, -PI * 0.42), Vector3(-28.0, tg.get_height(-28.0, -20.0), -20.0)),
			Transform3D(Basis(Vector3.UP, PI * 0.42), Vector3(28.0, tg.get_height(28.0, -20.0), -20.0)),
			Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(-38.0, tg.get_height(-38.0, 26.0), 26.0)),
			Transform3D(Basis(Vector3.UP, -PI * 0.25), Vector3(38.0, tg.get_height(38.0, 26.0), 26.0))
		]
		mm_fn.call("MultiMesh_FestivalGeoDomes", dome_mesh, d_xforms, 750.0, Color(1, 1, 1, 1), true)

	# 3. Spectator Grandstand Bleachers lining Starting Grid & Paddock Straight
	var bleacher_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/festival_bleacher.glb", 22.0, 0.02)
	if bleacher_mesh:
		var bl_xforms: Array[Transform3D] = []
		for bz: float in [-48.0, -34.0, -20.0, -6.0, 8.0, 22.0, 36.0]:
			for sx: float in [-18.5, 18.5]:
				if not clear_fn.call(sx, bz, 7.0, -1.0):
					continue
				var yaw: float = PI * 0.5 if sx < 0.0 else -PI * 0.5
				bl_xforms.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(sx, tg.get_height(sx, bz), bz)))
		mm_fn.call("MultiMesh_FestivalBleachers", bleacher_mesh, bl_xforms, 600.0, Color(1, 1, 1, 1), true)
		for bi: int in range(bl_xforms.size()):
			var xf: Transform3D = bl_xforms[bi]
			parent.add_child(VisualPipeline.build_box_occluder("Occluder_Bleacher_%d" % bi, Vector3(11.0, 4.2, 5.2), xf.origin + Vector3(0.0, 2.2, 0.0), xf.basis.get_euler().y))

	# 4. FIA Catch-Fence Barriers + Red/White Tire Stack Walls lining Hub Start Straight
	var catch_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/catchfence_barrier.glb", 1.0, 0.04)
	if catch_mesh:
		var cf_xforms: Array[Transform3D] = []
		for z_step: int in range(-66, 68, 8):
			var bz: float = float(z_step)
			for sx: float in [-12.2, 12.2]:
				if not clear_fn.call(sx, bz, 3.2, -1.0):
					continue
				var yaw: float = PI * 0.5 if sx < 0.0 else -PI * 0.5
				cf_xforms.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(sx, tg.get_height(sx, bz) + 0.15, bz)))
		mm_fn.call("MultiMesh_HubCatchFences", catch_mesh, cf_xforms, 380.0, Color(1, 1, 1, 1), false)

	var tire_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/tire_barrier_wall.glb", 1.15, 0.04)
	if tire_mesh:
		var t_xforms: Array[Transform3D] = []
		for z_step: int in range(-62, 62, 10):
			var bz: float = float(z_step)
			for sx: float in [-10.4, 10.4]:
				if not clear_fn.call(sx, bz, 2.0, -1.0):
					continue
				var yaw: float = PI * 0.5
				t_xforms.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(sx, tg.get_height(sx, bz) + 0.25, bz)))
		mm_fn.call("MultiMesh_HubTireBarriers", tire_mesh, t_xforms, 460.0, Color(1, 1, 1, 1), true)

	# 5. Concert Truss Pylons & Flood Light Towers
	var truss_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/concert_truss.glb", 2.8, 0.05)
	if truss_mesh:
		var tr_xforms: Array[Transform3D] = []
		for i: int in range(16):
			var ang: float = (float(i) / 16.0) * TAU
			var tx: float = cos(ang) * 78.0
			var tz: float = sin(ang) * 78.0
			if not clear_fn.call(tx, tz, 9.0, -1.0):
				continue
			tr_xforms.append(Transform3D(Basis(Vector3.UP, ang), Vector3(tx, tg.get_height(tx, tz), tz)))
		mm_fn.call("MultiMesh_FestivalTrusses", truss_mesh, tr_xforms, 650.0, Color(1, 1, 1, 1), true)

	var light_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/flood_lights/flood_lights.gltf", 1.85, 0.02, "standing_double_a")
	if light_mesh:
		var l_xforms: Array[Transform3D] = []
		for bz: float in [-58.0, -32.0, 16.0, 46.0]:
			for sx: float in [-16.2, 16.2]:
				if not clear_fn.call(sx, bz, 3.0, -1.0):
					continue
				var yaw: float = PI * 0.5 if sx < 0.0 else -PI * 0.5
				l_xforms.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(sx, tg.get_height(sx, bz), bz)))
		mm_fn.call("MultiMesh_HubFloodLights", light_mesh, l_xforms, 480.0, Color(1, 1, 1, 1), true)

	# Suppress unused parameter warning cleanly
	if rn == null:
		pass

static func _build_horizon_start_arch(parent: Node3D, tg: TerrainGenerator, base_pos: Vector3) -> void:
	var arch_root := Node3D.new()
	arch_root.name = "FestivalHorizonStartGantry"
	arch_root.position = base_pos

	var truss_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/concert_truss.glb", 3.1, 0.0)
	var steel_dark := StandardMaterial3D.new()
	steel_dark.albedo_color = Color(0.12, 0.13, 0.15)
	steel_dark.metallic = 0.82
	steel_dark.roughness = 0.28

	var led_amber := StandardMaterial3D.new()
	led_amber.albedo_color = Color(1.0, 0.42, 0.06)
	led_amber.emission_enabled = true
	led_amber.emission = Color(1.0, 0.44, 0.06)
	led_amber.emission_energy_multiplier = 2.0

	var led_cyan := StandardMaterial3D.new()
	led_cyan.albedo_color = Color(0.10, 0.78, 0.95)
	led_cyan.emission_enabled = true
	led_cyan.emission = Color(0.10, 0.80, 0.96)
	led_cyan.emission_energy_multiplier = 1.6

	# Detailed Sketchfab lattice steel columns on left and right flanking the 14m Starting Grid
	for sx: float in [-8.2, 8.2]:
		if truss_mesh:
			var col := MeshInstance3D.new()
			col.mesh = truss_mesh
			col.position = Vector3(sx, 0.0, 0.0)
			arch_root.add_child(col)
		var trim := MeshInstance3D.new()
		var t_box := BoxMesh.new()
		t_box.size = Vector3(0.14, 5.8, 0.16)
		trim.mesh = t_box
		trim.material_override = led_amber if sx < 0.0 else led_cyan
		trim.position = Vector3(sx + (-0.52 if sx < 0.0 else 0.52), 2.95, 0.52)
		arch_root.add_child(trim)

	# Sleek overhead aluminum bridge beam + FIA 5-light start gantry
	var header := MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(17.8, 0.92, 1.05)
	header.mesh = h_box
	header.material_override = steel_dark
	header.position = Vector3(0.0, 5.85, 0.0)
	arch_root.add_child(header)

	var bar_top := MeshInstance3D.new()
	var bt_box := BoxMesh.new()
	bt_box.size = Vector3(17.0, 0.12, 1.12)
	bar_top.mesh = bt_box
	bar_top.material_override = led_amber
	bar_top.position = Vector3(0.0, 6.26, 0.0)
	arch_root.add_child(bar_top)

	var bar_bot := MeshInstance3D.new()
	var bb_box := BoxMesh.new()
	bb_box.size = Vector3(17.0, 0.10, 1.12)
	bar_bot.mesh = bb_box
	bar_bot.material_override = led_cyan
	bar_bot.position = Vector3(0.0, 5.44, 0.0)
	arch_root.add_child(bar_bot)

	for li: int in range(5):
		var pod := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.17
		c_mesh.bottom_radius = 0.17
		c_mesh.height = 0.18
		pod.mesh = c_mesh
		pod.rotation.x = PI * 0.5
		pod.material_override = led_amber
		pod.position = Vector3(-2.6 + float(li) * 1.3, 5.85, 0.54)
		arch_root.add_child(pod)

	parent.add_child(arch_root)
	if tg == null:
		pass

static func build_coast_harbor_depot(parent: Node3D, tg: TerrainGenerator, clear_fn: Callable, mm_fn: Callable) -> void:
	var c_rust: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/shipping_container_rust.glb", 0.46, 0.02)
	var c_blue: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/props/shipping_container_blue.glb", 1.02, 0.02)

	var x_rust: Array[Transform3D] = []
	var x_blue: Array[Transform3D] = []
	for r: int in range(8):
		for c: int in range(3):
			var cx: float = 1915.0 + float(c) * 11.0 + float(r % 2) * 3.5
			var cz: float = 1140.0 + float(r) * 18.0
			if not clear_fn.call(cx, cz, 11.5, -1.0):
				continue
			var cy: float = tg.get_height(cx, cz)
			if cy < 2.2:
				continue
			var yaw: float = 0.14 if (r % 2 == 0) else -0.08
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(cx, cy, cz))
			if (r + c) % 2 == 0:
				x_rust.append(xf)
				if r % 3 == 0:
					x_blue.append(Transform3D(Basis(Vector3.UP, yaw + 0.04), Vector3(cx, cy + 2.55, cz)))
			else:
				x_blue.append(xf)
	if c_rust:
		mm_fn.call("MultiMesh_HarborContainersRust", c_rust, x_rust, 850.0, Color(1, 1, 1, 1), true)
	if c_blue:
		mm_fn.call("MultiMesh_HarborContainersBlue", c_blue, x_blue, 850.0, Color(1, 1, 1, 1), true)
	for ci: int in range(mini(x_rust.size(), 12)):
		var xf_c: Transform3D = x_rust[ci]
		parent.add_child(VisualPipeline.build_box_occluder("Occluder_Container_%d" % ci, Vector3(5.6, 2.2, 2.2), xf_c.origin + Vector3(0.0, 1.2, 0.0), xf_c.basis.get_euler().y))

	# Concrete port apron & wooden pier stretching cleanly out over Neon Coast surf
	var pier_mat := StandardMaterial3D.new()
	pier_mat.albedo_color = Color(0.28, 0.22, 0.16)
	pier_mat.roughness = 0.85
	var deck := MeshInstance3D.new()
	deck.name = "Mesh_NeonCoastPier"
	var p_box := BoxMesh.new()
	p_box.size = Vector3(58.0, 0.9, 14.0)
	deck.mesh = p_box
	deck.material_override = pier_mat
	deck.position = Vector3(2195.0, 2.8, 1210.0)
	parent.add_child(deck)

static func build_dust_bowl_monuments(tg: TerrainGenerator, rn: RoadNetwork, clear_fn: Callable, mm_fn: Callable) -> void:
	var arch_mesh: Mesh = PropMeshUtils.load_centered_mesh("res://assets/models/rocks/sandstone_arch.glb", 14.5, 0.85)
	if not arch_mesh:
		return
	var arch_xforms: Array[Transform3D] = []
	var candidates: Array[Vector2] = [
		Vector2(-1060.0, 1020.0),
		Vector2(-1390.0, 1410.0),
		Vector2(-740.0, 740.0),
		Vector2(-1780.0, 1740.0)
	]
	for pt: Vector2 in candidates:
		if not clear_fn.call(pt.x, pt.y, 16.0, -1.0):
			continue
		var y: float = tg.get_height(pt.x, pt.y)
		arch_xforms.append(Transform3D(Basis(Vector3.UP, 0.85), Vector3(pt.x, y, pt.y)))
	mm_fn.call("MultiMesh_DustBowlSandstoneArches", arch_mesh, arch_xforms, 1400.0, Color(1.04, 0.88, 0.76), true)
	if rn == null:
		pass

static func build_volcano_caldera_plume(parent: Node3D, tg: TerrainGenerator) -> void:
	# Atmospheric rising ash/steam plume hovering above La Gran Caldera (980, -1140)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for py: int in range(64):
		for px: int in range(64):
			var r: float = Vector2(float(px) - 31.5, float(py) - 31.5).length() / 31.5
			var a: float = clampf(1.0 - smoothstep(0.05, 0.98, r), 0.0, 1.0)
			img.set_pixel(px, py, Color(0.78, 0.76, 0.78, a * a * 0.42))
	var smoke_tex := ImageTexture.create_from_image(img)

	var smk := GPUParticles3D.new()
	smk.name = "VolcanoCalderaPlume"
	smk.position = Vector3(980.0, tg.get_height(980.0, -1140.0) + 18.0, -1140.0)
	smk.amount = 42
	smk.lifetime = 9.0
	smk.preprocess = 5.0
	smk.visibility_aabb = AABB(Vector3(-400, -100, -400), Vector3(800, 600, 800))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_radius = 95.0
	pmat.emission_ring_inner_radius = 12.0
	pmat.emission_ring_axis = Vector3.UP
	pmat.direction = Vector3(0.18, 1.0, -0.10).normalized()
	pmat.spread = 22.0
	pmat.initial_velocity_min = 9.0
	pmat.initial_velocity_max = 16.0
	pmat.gravity = Vector3(0.4, 0.25, -0.2)
	pmat.scale_min = 42.0
	pmat.scale_max = 78.0
	smk.process_material = pmat

	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = smoke_tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.42, 0.36, 0.34, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.65, 0.25, 0.08)
	mat.emission_energy_multiplier = 0.22
	q.material = mat
	smk.draw_pass_1 = q
	parent.add_child(smk)
