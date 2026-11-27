# scripts/core/horizon_compositor_effect.gd
# Forward+ Vulkan RenderingDevice CompositorEffect compute pass:
# Delivers subtle optical micro-clarity sharpening (offsetting TAA/FSR2 softness) and speed-reactive lens vignette.
@tool
class_name HorizonCompositorEffect
extends CompositorEffect

@export_range(0.0, 0.4) var clarity_strength: float = 0.14
@export_range(0.0, 0.35) var vignette_strength: float = 0.14

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _speed_norm: float = 0.0

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	needs_motion_vectors = false
	_rd = RenderingServer.get_rendering_device()
	if _rd:
		RenderingServer.call_on_render_thread(_initialize_compute)

func set_speed_norm(val: float) -> void:
	_speed_norm = clampf(val, 0.0, 1.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _rd and _shader.is_valid():
			_rd.free_rid(_shader)
			_shader = RID()
			_pipeline = RID()

func _initialize_compute() -> void:
	if not _rd or _shader.is_valid():
		return

	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = """
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float clarity;
	float vignette;
} params;

void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	vec4 center = imageLoad(color_image, uv);
	ivec2 max_c = size - ivec2(1);
	vec3 n = imageLoad(color_image, clamp(uv + ivec2(0, -1), ivec2(0), max_c)).rgb;
	vec3 s = imageLoad(color_image, clamp(uv + ivec2(0, 1), ivec2(0), max_c)).rgb;
	vec3 e = imageLoad(color_image, clamp(uv + ivec2(1, 0), ivec2(0), max_c)).rgb;
	vec3 w = imageLoad(color_image, clamp(uv + ivec2(-1, 0), ivec2(0), max_c)).rgb;

	// Edge-clamped optical clarity unsharp mask (restores road aggregate & clearcoat edge crispness)
	vec3 blur = (n + s + e + w) * 0.25;
	vec3 detail = clamp(center.rgb - blur, vec3(-0.18), vec3(0.18));
	vec3 out_rgb = max(vec3(0.0), center.rgb + detail * params.clarity);

	// Gentle cinematic radial optical vignette
	vec2 ndc = (vec2(uv) + 0.5) / params.raster_size * 2.0 - 1.0;
	float r2 = dot(ndc, ndc);
	float vig = 1.0 - smoothstep(0.45, 1.85, r2) * params.vignette;
	out_rgb *= vig;

	imageStore(color_image, uv, vec4(out_rgb, center.a));
}
"""
	var spirv: RDShaderSPIRV = _rd.shader_compile_spirv_from_source(src)
	if not spirv or not spirv.compile_error_compute.is_empty():
		printerr("[HorizonCompositorEffect] Compute compile error: ", spirv.compile_error_compute if spirv else "null")
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if _shader.is_valid():
		_pipeline = _rd.compute_pipeline_create(_shader)

func _render_callback(p_effect_callback_type: int, p_render_data: RenderData) -> void:
	if not _rd or not _pipeline.is_valid():
		return
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return

	var rsb: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not rsb:
		return

	var size: Vector2i = rsb.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var x_groups: int = int((size.x - 1) / 8) + 1
	var y_groups: int = int((size.y - 1) / 8) + 1

	var push := PackedFloat32Array([
		float(size.x),
		float(size.y),
		clarity_strength + _speed_norm * 0.06,
		vignette_strength + _speed_norm * 0.12
	])

	var view_count: int = rsb.get_view_count()
	for view: int in range(view_count):
		var input_image: RID = rsb.get_color_layer(view)
		if not input_image.is_valid():
			continue
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u.binding = 0
		u.add_id(input_image)
		var uniform_set: RID = UniformSetCacheRD.get_cache(_shader, 0, [u])
		var cl: int = _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(cl, _pipeline)
		_rd.compute_list_bind_uniform_set(cl, uniform_set, 0)
		_rd.compute_list_set_push_constant(cl, push.to_byte_array(), push.size() * 4)
		_rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
		_rd.compute_list_end()
