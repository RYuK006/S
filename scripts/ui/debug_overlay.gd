# scripts/ui/debug_overlay.gd
# F3 Debug telemetry overlay (PC F3 / Mobile 3-finger tap): displays FPS, VRAM budget,
# physics frame time, draw/tri counts, DRS scale, audio activity, and 4-wheel Pacejka dynamics.
class_name DebugOverlay
extends Control

var target_vehicle: Node3D
var label: Label
var panel: PanelContainer
var is_visible_overlay: bool = false
var touch_points: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	panel = PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.84)
	style.border_width_left = 2
	style.border_color = Color(1.0, 0.45, 0.05, 0.9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	label = Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	label.text = "GRIDLETHAL TELEMETRY"
	panel.add_child(label)

	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	for arg: String in all_args:
		if arg == "--telemetry":
			is_visible_overlay = true
	visible = is_visible_overlay

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_f3"):
		toggle_visible()
	elif event is InputEventScreenTouch:
		var ev_t: InputEventScreenTouch = event as InputEventScreenTouch
		if ev_t.pressed:
			touch_points[ev_t.index] = ev_t.position
			if touch_points.size() >= 3:
				toggle_visible()
		else:
			touch_points.erase(ev_t.index)

func toggle_visible() -> void:
	is_visible_overlay = not is_visible_overlay
	visible = is_visible_overlay

func set_target_vehicle(vehicle: Node3D) -> void:
	target_vehicle = vehicle

func _process(delta: float) -> void:
	if not visible or not label:
		return
		
	var fps: int = int(Engine.get_frames_per_second())
	var frame_ms: float = delta * 1000.0
	var phys_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var vid_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var tex_mb: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var buf_mb: float = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0
	var drs_scale: float = get_viewport().scaling_3d_scale if get_viewport() else 1.0
	var master_db: float = AudioServer.get_bus_peak_volume_left_db(0, 0)
	
	var text: String = "=== GRIDLETHAL TELEMETRY (F3 / 3-Finger Tap) ===\n"
	text += "FPS: %d (%.2f ms) | Physics: %.2f ms @ %d Hz | DRS Scale: %.2f\n" % [fps, frame_ms, phys_ms, Engine.physics_ticks_per_second, drs_scale]
	text += "Draw Calls: %d | Tris: %dk | VRAM: %.0f / 5120 MB (Tex %.0f MB, Buf %.0f MB)\n" % [draw_calls, int(primitives / 1000.0), vid_mb, tex_mb, buf_mb]
	text += "Audio Peak: %.1f dBFS | Buses: %d\n" % [master_db, AudioServer.bus_count]
	
	if target_vehicle and "speed_kmh" in target_vehicle:
		var speed_kmh: float = float(target_vehicle.get("speed_kmh"))
		var speed_mph: float = speed_kmh * 0.621371
		var rpm: int = int(target_vehicle.get("engine_rpm"))
		var gear: int = int(target_vehicle.get("current_gear"))
		var gear_str: String = "R" if gear == 0 else str(gear)
		var thr: float = float(target_vehicle.get("throttle_input")) * 100.0
		var brk: float = float(target_vehicle.get("brake_input")) * 100.0
		var str_ang: float = rad_to_deg(float(target_vehicle.get("steer_input")))
		text += "Speed: %.1f km/h (%.1f mph) | Gear: %s | RPM: %d\n" % [speed_kmh, speed_mph, gear_str, rpm]
		text += "Throttle: %.0f%% | Brake: %.0f%% | Steer: %.1f deg\n" % [thr, brk, str_ang]
		
		if "nitro_amount" in target_vehicle:
			text += "Nitro: %.0f%% | Health: %.0f / %.0f\n" % [
				float(target_vehicle.get("nitro_amount")),
				float(target_vehicle.get("health")),
				float(target_vehicle.get("max_health"))
			]
		
		if "wheels" in target_vehicle and target_vehicle.wheels.size() == 4:
			text += "--- WHEEL TELEMETRY (Pacejka Dynamics) ---\n"
			var w_labels: Array[String] = ["FL", "FR", "RL", "RR"]
			for i: int in range(4):
				var w = target_vehicle.wheels[i]
				text += "[%s] Comp: %.1fcm | Fz: %.0fN | SlipA: %.1f° | SlipR: %.2f | %s (μ=%.2f)\n" % [
					w_labels[i],
					w.compression * 100.0,
					w.normal_force,
					rad_to_deg(w.slip_angle),
					w.slip_ratio,
					w.surface_type,
					w.surface_mu
				]
	else:
		text += "Mode: Showroom / Menu Showcase\n"
		
	label.text = text
