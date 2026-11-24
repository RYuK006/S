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
	
	var text = "=== GRIDLETHAL ENGINE TELEMETRY (F3 to toggle) ===\n"
	text += "FPS: %d (%.2f ms) | Physics Rate: %d Hz\n" % [fps, frame_ms, Engine.physics_ticks_per_second]
	
	if target_vehicle and "speed_kmh" in target_vehicle:
		var speed_kmh = target_vehicle.get("speed_kmh")
		var speed_mph = speed_kmh * 0.621371
		var rpm = int(target_vehicle.get("engine_rpm"))
		var gear = target_vehicle.get("current_gear")
		var gear_str = "R" if gear == 0 else str(gear)
		text += "Speed: %.1f km/h (%.1f mph) | RPM: %d | Gear: %s\n" % [speed_kmh, speed_mph, rpm, gear_str]
		
		if "nitro_amount" in target_vehicle:
			text += "Nitro: %.0f%% | Health: %.0f / %.0f\n" % [
				target_vehicle.get("nitro_amount"),
				target_vehicle.get("health"),
				target_vehicle.get("max_health")
			]
	else:
		text += "Vehicle: Standby / Menu Mode\n"
		
	label.text = text
