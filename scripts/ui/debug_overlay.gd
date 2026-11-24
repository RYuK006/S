# debug_overlay.gd
# F3 Debug telemetry overlay: displays frame metrics, vehicle kinematics, Pacejka slip and audio states.
class_name DebugOverlay
extends Control

var target_vehicle: Node3D
var label: Label
var is_visible_overlay: bool = true
var touch_points: Dictionary = {}

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var panel = PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	
	label = Label.new()
	label.text = "GRIDLETHAL TELEMETRY"
	panel.add_child(label)

func _input(event: InputEvent):
	if event.is_action_pressed("debug_f3"):
		toggle_visible()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() >= 3:
				toggle_visible()
		else:
			touch_points.erase(event.index)

func toggle_visible():
	is_visible_overlay = !is_visible_overlay
	visible = is_visible_overlay

func set_target_vehicle(vehicle: Node3D):
	target_vehicle = vehicle

func _process(delta: float):
	if not visible:
		return
		
	var fps = Engine.get_frames_per_second()
	var frame_ms = delta * 1000.0
	var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	
	var text = "=== GRIDLETHAL TELEMETRY (F3 to toggle) ===\n"
	text += "FPS: %d (%.2f ms) | Draw Calls: %d | Primitives: %d\n" % [fps, frame_ms, draw_calls, primitives]
	text += "Physics Rate: %d Hz\n" % [Engine.physics_ticks_per_second]
	
	if target_vehicle and "speed_kmh" in target_vehicle:
		var speed_kmh: float = target_vehicle.get("speed_kmh")
		var speed_mph: float = speed_kmh * 0.621371
		var rpm: int = int(target_vehicle.get("engine_rpm"))
		var gear = target_vehicle.get("current_gear")
		var gear_str: String = "R" if gear == 0 else str(gear)
		var thr: float = target_vehicle.get("throttle_input") * 100.0
		var brk: float = target_vehicle.get("brake_input") * 100.0
		var str_ang: float = rad_to_deg(target_vehicle.get("steer_input"))
		text += "Speed: %.1f km/h (%.1f mph) | Gear: %s | RPM: %d\n" % [speed_kmh, speed_mph, gear_str, rpm]
		text += "Throttle: %.0f%% | Brake: %.0f%% | Steer: %.1f deg\n" % [thr, brk, str_ang]
		
		if "nitro_amount" in target_vehicle:
			text += "Nitro: %.0f%% | Health: %.0f / %.0f\n" % [
				target_vehicle.get("nitro_amount"),
				target_vehicle.get("health"),
				target_vehicle.get("max_health")
			]
		
		if "wheels" in target_vehicle and target_vehicle.wheels.size() == 4:
			text += "\n--- WHEEL TELEMETRY (Pacejka Dynamics) ---\n"
			var w_labels = ["FL", "FR", "RL", "RR"]
			for i in range(4):
				var w = target_vehicle.wheels[i]
				text += "[%s] Comp: %.1fcm | Fz: %.0fN | SlipAngle: %.1f deg | SlipRatio: %.2f | Surf: %s (mu=%.2f)\n" % [
					w_labels[i],
					w.compression * 100.0,
					w.normal_force,
					rad_to_deg(w.slip_angle),
					w.slip_ratio,
					w.surface_type,
					w.surface_mu
				]
	else:
		text += "Vehicle: Standby / Menu Mode\n"
		
	label.text = text
