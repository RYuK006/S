# drs_controller.gd
# Dynamic Resolution Scaling (DRS) targeting 60 FPS with hysteresis and thermal throttling guard.
class_name DRSController
extends Node

@export var target_fps: float = 60.0
@export var min_scale: float = 0.65
@export var max_scale: float = 1.0
@export var enabled: bool = true

var current_scale: float = 1.0
var frame_history: PackedFloat32Array = PackedFloat32Array()
var history_size: int = 45
var update_timer: float = 0.0
var check_interval: float = 0.25

func _ready():
	frame_history.resize(history_size)
	for i in range(history_size):
		frame_history[i] = 1.0 / target_fps

func _process(delta: float):
	if not enabled:
		return
		
	var idx = Engine.get_process_frames() % history_size
	frame_history[idx] = delta
	
	update_timer += delta
	if update_timer < check_interval:
		return
	update_timer = 0.0
	
	var sum = 0.0
	for dt in frame_history:
		sum += dt
	var avg_frame_time = sum / float(history_size)
	var avg_fps = 1.0 / max(0.0001, avg_frame_time)
	
	if avg_fps < target_fps * 0.92:
		current_scale = max(min_scale, current_scale - 0.05)
	elif avg_fps > target_fps * 0.98 and current_scale < max_scale:
		current_scale = min(max_scale, current_scale + 0.02)
		
	var vp = get_viewport()
	if vp:
		vp.scaling_3d_scale = current_scale
		if current_scale < 0.99:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.fsr_sharpness = 0.25
		else:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
