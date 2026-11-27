# scripts/core/visual_pipeline.gd
# Shared Forward+ Near-AAA Visual Pipeline: AgX tonemapping, Soft Light bloom, half-res SSIL/SSR,
# aerial perspective, LightmapGI + OccluderInstance3D helpers, and startup shader pre-warming.
class_name VisualPipeline
extends RefCounted

const HorizonCompositorEffect = preload("res://scripts/core/horizon_compositor_effect.gd")

static func attach_horizon_compositor(world_env: WorldEnvironment, clarity: float = 0.14, vignette: float = 0.12) -> HorizonCompositorEffect:
	if not world_env or RenderingServer.get_rendering_device() == null:
		return null
	var eff := HorizonCompositorEffect.new()
	eff.clarity_strength = clarity
	eff.vignette_strength = vignette
	var comp := world_env.compositor
	if not comp:
		comp = Compositor.new()
		world_env.compositor = comp
	var arr: Array[CompositorEffect] = comp.compositor_effects.duplicate()
	arr.append(eff)
	comp.compositor_effects = arr
	return eff

static func apply_aaa_environment(env: Environment, preset: String = "outdoor") -> void:
	if not env:
		return

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.sdfgi_enabled = false

	# AgX Filmic Highlight Roll-Off + Punchy Zero-Cost Contrast
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_agx_white = 14.5
	env.tonemap_agx_contrast = 1.20 if preset != "studio" else 1.22

	# Ambient-Only Contact Shadows (light_affect = 0.0 avoids staining direct sunlight)
	env.ssao_enabled = true
	env.ssao_radius = 1.55
	env.ssao_intensity = 2.25
	env.ssao_power = 1.65
	env.ssao_light_affect = 0.0

	# Half-Res Screen-Space Indirect Lighting (Subtle Color Bleed Bounce)
	env.ssil_enabled = true
	env.ssil_radius = 4.5
	env.ssil_intensity = 0.72

	# Temporally Stable Rewritten SSR (Wet Puddles, Car Clearcoat, Showroom Floor)
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.12

	# Subtle Soft Light Bloom on Specular Highlights, Brake Lights & Molten Lava
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_normalized = false
	env.glow_intensity = 0.24
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.15

	if preset == "studio":
		env.fog_enabled = false
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0014
		env.volumetric_fog_length = 64.0
		env.volumetric_fog_anisotropy = 0.55
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.02
		env.adjustment_contrast = 1.06
		env.adjustment_saturation = 1.08
	else:
		# Atmospheric Aerial Perspective scattering distance into true sky color while keeping sky crisp
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_aerial_perspective = 1.0
		env.fog_sky_affect = 0.0
		env.fog_sun_scatter = 0.42
		env.fog_density = 0.12 if preset == "outdoor" else 0.08
		env.fog_depth_begin = 680.0 if preset == "outdoor" else 340.0
		env.fog_depth_end = 4200.0 if preset == "outdoor" else 2200.0
		env.fog_height = 12.0
		env.fog_height_density = 0.006

		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0018 if preset == "outdoor" else 0.0022
		env.volumetric_fog_length = 84.0
		env.volumetric_fog_anisotropy = 0.58
		env.volumetric_fog_gi_inject = 0.55
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_temporal_reprojection_enabled = true

		env.adjustment_enabled = true
		env.adjustment_brightness = 1.03
		env.adjustment_contrast = 1.07
		env.adjustment_saturation = 1.12


static func configure_directional_sun(sun: DirectionalLight3D, max_dist: float = 480.0) -> void:
	if not sun:
		return
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = max_dist
	sun.directional_shadow_split_1 = 0.03
	sun.directional_shadow_split_2 = 0.12
	sun.directional_shadow_split_3 = 0.36
	sun.light_bake_mode = Light3D.BAKE_DYNAMIC


static func build_box_occluder(occ_name: String, box_size: Vector3, world_pos: Vector3, rot_y: float = 0.0) -> OccluderInstance3D:
	var occ := OccluderInstance3D.new()
	occ.name = occ_name
	var box := BoxOccluder3D.new()
	box.size = box_size
	occ.occluder = box
	occ.position = world_pos
	occ.rotation.y = rot_y
	return occ


static func setup_lightmap_gi(parent: Node3D, bake_extents: Vector3, quality: int = 2, data_path: String = "") -> LightmapGI:
	var lgi := LightmapGI.new()
	lgi.name = "StaticLightmapGI"
	lgi.quality = quality as LightmapGI.BakeQuality
	lgi.bounces = 3
	lgi.directional = true
	lgi.use_texture_for_bounces = true
	lgi.supersampling = true
	lgi.supersampling_factor = 2.0
	lgi.denoiser_strength = 0.1
	lgi.denoiser_range = 10
	lgi.environment_mode = LightmapGI.ENVIRONMENT_MODE_SCENE
	lgi.generate_probes_subdiv = LightmapGI.GENERATE_PROBES_SUBDIV_4
	if not data_path.is_empty() and ResourceLoader.exists(data_path):
		var ld: Resource = ResourceLoader.load(data_path)
		if ld is LightmapGIData:
			lgi.light_data = ld as LightmapGIData
	parent.add_child(lgi)
	# Keep uniform probe hint nearby so LightmapGI covers bounds cleanly when baked
	var p_probe := LightmapProbe.new()
	p_probe.name = "CenterProbe"
	p_probe.position = Vector3(0.0, minf(bake_extents.y * 0.25, 2.5), 0.0)
	parent.add_child(p_probe)
	return lgi


static func collect_materials_from_node(root: Node, out: Array[Material], seen_ids: Dictionary = {}) -> void:
	if not root:
		return
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root as MeshInstance3D
		if mi.material_override and not seen_ids.has(mi.material_override.get_instance_id()):
			seen_ids[mi.material_override.get_instance_id()] = true
			out.append(mi.material_override)
		if mi.mesh:
			for s: int in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_active_material(s)
				if mat and not seen_ids.has(mat.get_instance_id()):
					seen_ids[mat.get_instance_id()] = true
					out.append(mat)
	elif root is MultiMeshInstance3D:
		var mmi: MultiMeshInstance3D = root as MultiMeshInstance3D
		if mmi.multimesh and mmi.multimesh.mesh:
			for s: int in range(mmi.multimesh.mesh.get_surface_count()):
				var mat: Material = mmi.multimesh.mesh.surface_get_material(s)
				if mat and not seen_ids.has(mat.get_instance_id()):
					seen_ids[mat.get_instance_id()] = true
					out.append(mat)
	for c: Node in root.get_children():
		collect_materials_from_node(c, out, seen_ids)


static func spawn_prewarm_batch(host: Node3D, camera: Camera3D, materials: Array[Material]) -> void:
	if not host or materials.is_empty():
		return
	var runner := _ShaderPrewarmNode.new()
	runner.name = "ShaderPrewarmer"
	runner.setup(camera, materials)
	host.add_child(runner)


class _ShaderPrewarmNode extends Node3D:
	var _cam: Camera3D
	var _mats: Array[Material] = []
	var _frames: int = 0

	func setup(cam: Camera3D, mats: Array[Material]) -> void:
		_cam = cam
		_mats = mats

	func _ready() -> void:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.008, 0.008)
		var count: int = mini(_mats.size(), 96)
		for i: int in range(count):
			var mi := MeshInstance3D.new()
			mi.mesh = quad
			mi.material_override = _mats[i]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var gx: float = float(i % 12 - 6) * 0.012
			var gy: float = float(i / 12 - 4) * 0.012
			mi.position = Vector3(gx, gy, -1.6)
			add_child(mi)
		_sync_to_camera()

	func _sync_to_camera() -> void:
		if _cam and is_instance_valid(_cam):
			global_transform = _cam.global_transform

	func _process(_delta: float) -> void:
		_sync_to_camera()
		_frames += 1
		if _frames >= 3:
			queue_free()
